import pytest
from sqlalchemy import delete

from app.models.team import Team, TeamStatus
from app.models.team_membership import TeamMembership
from app.models.user import User
from tests.test_answer_governance import headers, seed_governance


async def seed_scope(factory):
    ids = await seed_governance(factory)
    async with factory() as session:
        team = Team(organisation_id=ids['organisation'], name='Restricted team')
        second = Team(organisation_id=ids['organisation'], name='Other team')
        session.add_all([team, second])
        await session.flush()
        for team_id, user in [(team.id, 'employee'), (team.id, 'finance_owner'),
                              (second.id, 'employee')]:
            session.add(TeamMembership(organisation_id=ids['organisation'],
                                       team_id=team_id, user_id=ids[user]))
        await session.commit()
        ids.update(team=team.id, second_team=second.id)
    return ids


@pytest.mark.asyncio
@pytest.mark.parametrize('visibility', ['department', 'team'])
async def test_restricted_question_surfaces_and_membership_revocation(app_client, visibility):
    client, factory = app_client
    ids = await seed_scope(factory)
    payload = {'title': 'F12 secret vault', 'body': 'Restricted question detail',
               'visibility': visibility, 'department_id': str(ids['finance_department']),
               'team_id': str(ids['team'])}
    created = await client.post('/api/v1/questions', headers=headers(ids, 'employee'), json=payload)
    assert created.status_code == 201, created.text
    question_id = created.json()['id']
    base = f'/api/v1/questions/{question_id}'
    answer = await client.post(base + '/answers', headers=headers(ids, 'employee'),
                               json={'body': 'F12 restricted answer'})
    assert answer.status_code == 201
    answer_id = answer.json()['id']
    assert (await client.post(base + '/comments', headers=headers(ids, 'employee'),
                              json={'body': 'F12 private discussion'})).status_code == 201
    for actor in ['employee', 'finance_owner', 'people_owner', 'admin', 'outsider']:
        allowed = actor in ['employee', 'finance_owner']
        expected = 200 if allowed else (404 if actor == 'outsider' else 403)
        for path in [base, base + '/answers', base + '/comments', base + '/versions',
                     f'/api/v1/answers/{answer_id}/versions',
                     f'/api/v1/answers/{answer_id}/challenges']:
            response = await client.get(path, headers=headers(ids, actor))
            assert response.status_code == expected, (actor, path, response.text)
            if not allowed:
                assert 'F12' not in response.text
        listed = await client.get('/api/v1/questions', headers=headers(ids, actor))
        if actor == 'outsider':
            assert listed.status_code == 404
            continue
        assert listed.status_code == 200, listed.text
        assert (question_id in {item['id'] for item in listed.json()}) == allowed
        search = await client.post('/api/v1/questions/search', headers=headers(ids, actor),
                                   json={'query': 'F12 secret vault', 'include_unanswered': True})
        assert search.status_code == 200
        assert (question_id in {item['question_id'] for item in search.json()}) == allowed
        if not allowed:
            assert 'Restricted question detail' not in search.text
            assert (await client.post(base + '/answers', headers=headers(ids, actor),
                                      json={'body': 'Unauthorized write'})).status_code == expected
            assert (await client.post(base + '/comments', headers=headers(ids, actor),
                                      json={'body': 'Unauthorized write'})).status_code == expected
    # Even the author loses restricted access when membership is removed.
    async with factory() as session:
        if visibility == 'team':
            await session.execute(delete(TeamMembership).where(
                TeamMembership.team_id == ids['team'], TeamMembership.user_id == ids['employee']))
        else:
            (await session.get(User, ids['employee'])).department_id = ids['people_department']
        await session.commit()
    assert (await client.get(base, headers=headers(ids, 'employee'))).status_code == 403
    search = await client.post('/api/v1/questions/search', headers=headers(ids, 'employee'),
                               json={'query': 'F12 secret vault', 'include_unanswered': True})
    assert question_id not in {item['question_id'] for item in search.json()}


@pytest.mark.asyncio
async def test_explicit_visibility_validation_and_assignment_independence(app_client):
    client, factory = app_client
    ids = await seed_scope(factory)
    create = lambda data: client.post('/api/v1/questions', headers=headers(ids, 'employee'), json=data)
    for visibility in ['department', 'team']:
        response = await create({'title': 'Missing scope', 'visibility': visibility})
        assert response.status_code == 409
    assert (await create({'title': 'Wrong department', 'visibility': 'department',
                          'department_id': str(ids['people_department'])})).status_code == 403
    assert (await client.post('/api/v1/questions', headers=headers(ids, 'people_owner'), json={
        'title': 'Not a team member', 'visibility': 'team', 'team_id': str(ids['team'])})).status_code == 403
    # Assignment alone continues to direct responsibility without restricting reads.
    public = await create({'title': 'Organisation assignment', 'team_id': str(ids['team']),
                           'department_id': str(ids['finance_department'])})
    assert public.status_code == 201
    base = '/api/v1/questions/' + public.json()['id']
    assert (await client.get(base, headers=headers(ids, 'people_owner'))).status_code == 200
    # Explicit restriction also works for existing uncontributed questions.
    assert (await client.patch(base, headers=headers(ids, 'employee'), json={'visibility': 'team'})).status_code == 200
    assert (await client.get(base, headers=headers(ids, 'people_owner'))).status_code == 403
    assert (await client.patch(base, headers=headers(ids, 'employee'), json={'team_id': None})).status_code == 409
    # Multiple-team membership works; a removed team cannot provide access.
    second = await create({'title': 'Second team', 'visibility': 'team', 'team_id': str(ids['second_team'])})
    assert second.status_code == 201
    async with factory() as session:
        (await session.get(Team, ids['second_team'])).status = TeamStatus.INACTIVE
        await session.commit()
    assert (await client.get('/api/v1/questions/' + second.json()['id'], headers=headers(ids, 'employee'))).status_code == 403


@pytest.mark.asyncio
async def test_merge_cannot_copy_restricted_answer_to_organisation_audience(app_client):
    client, factory = app_client
    ids = await seed_scope(factory)
    # A legacy admin is a member of both audiences; management is not disclosure authority.
    async with factory() as session:
        session.add(TeamMembership(organisation_id=ids['organisation'], team_id=ids['team'], user_id=ids['admin']))
        await session.commit()
    restricted = await client.post('/api/v1/questions', headers=headers(ids), json={
        'title': 'Restricted merge source', 'visibility': 'team', 'team_id': str(ids['team'])})
    source = restricted.json()['id']
    answer = await client.post(f'/api/v1/questions/{source}/answers', headers=headers(ids), json={'body': 'Secret merge answer'})
    result = await client.post(f"/api/v1/questions/{ids['finance_question']}/merge", headers=headers(ids), json={
        'duplicate_question_ids': [source], 'canonical_answer_id': answer.json()['id'], 'reason': 'Test boundary'})
    assert result.status_code == 409, result.text
    visible = await client.get(f"/api/v1/questions/{ids['finance_question']}", headers=headers(ids, 'people_owner'))
    assert 'Secret merge answer' not in visible.text

from uuid import UUID

import pytest
from sqlalchemy import select

from app.models.audit_event import AuditAction, AuditEvent
from tests.test_answer_governance import headers, seed_governance
from tests.test_guided import add_participant, add_question, answer, create_session
from tests.test_guided_safety import row_counts


@pytest.mark.asyncio
@pytest.mark.parametrize('visibility', ['private', 'organisation'])
async def test_completed_session_blocks_all_content_writes_until_explicit_reopen(app_client, visibility):
    client, factory = app_client
    ids = await seed_governance(factory)
    guided = await create_session(client, ids)
    base = f"/api/v1/guided/sessions/{guided['id']}"
    if visibility == 'organisation':
        assert (await client.patch(base, headers=headers(ids, 'employee'), json={'visibility': visibility})).status_code == 200
    participant = await add_participant(client, ids, guided['id'], 'Alice')
    question = await add_question(client, ids, guided['id'], 'Original question')
    saved = await answer(client, ids, question['id'], participant['id'], 'Finished answer')
    # Retain a deleted node to prove restore is a mutation too.
    deleted = await add_question(client, ids, guided['id'], 'Deleted question')
    assert (await client.delete(f"/api/v1/guided/questions/{deleted['id']}", headers=headers(ids, 'employee'))).status_code == 200
    started = await client.post(base + '/start', headers=headers(ids, 'employee'))
    assert started.status_code == 200
    completed = await client.post(base + '/complete', headers=headers(ids, 'employee'))
    assert completed.status_code == 200
    completed_revision = completed.json()['revision']
    before = await row_counts(factory)
    snapshot = await client.get(base + '/export/json', headers=headers(ids, 'employee'))
    assert snapshot.status_code == 200
    mutations = [
        ('PATCH', base, {'title': 'Changed details'}),
        ('POST', base + '/participants', {'name': 'Bob'}),
        ('PATCH', f"/api/v1/guided/participants/{participant['id']}", {'name': 'Changed name'}),
        ('DELETE', f"/api/v1/guided/participants/{participant['id']}", None),
        ('POST', base + '/questions', {'text': 'New question', 'scope': 'shared'}),
        ('PATCH', f"/api/v1/guided/questions/{question['id']}", {'text': 'Changed question'}),
        ('DELETE', f"/api/v1/guided/questions/{question['id']}", None),
        ('POST', f"/api/v1/guided/questions/{deleted['id']}/restore", None),
        ('POST', f"/api/v1/guided/questions/{question['id']}/answers", {'participant_id': participant['id'], 'body': 'New answer'}),
        ('PATCH', f"/api/v1/guided/answers/{saved['id']}", {'body': 'Changed answer'}),
        ('PATCH', f"/api/v1/guided/answers/{saved['id']}", {'branches_collapsed': True}),
        ('POST', f"/api/v1/guided/answers/{saved['id']}/follow-ups", {'text': 'New follow-up'}),
    ]
    for method, path, payload in mutations:
        response = await client.request(method, path, headers=headers(ids, 'employee'), json=payload)
        assert response.status_code == 409, (method, path, response.text)
    assert await row_counts(factory) == before
    after = await client.get(base + '/export/json', headers=headers(ids, 'employee'))
    # Export metadata can change; the retained session graph cannot.
    assert after.json()['session'] == snapshot.json()['session']
    assert (await client.get(base, headers=headers(ids, 'employee'))).status_code == 200
    assert (await client.get(base + '/export/csv', headers=headers(ids, 'employee'))).status_code == 200
    assert (await client.get(base + '/revisions', headers=headers(ids, 'employee'))).status_code == 200
    assert (await client.post(base + '/start', headers=headers(ids, 'employee'))).status_code == 409
    assert (await client.post(base + '/complete', headers=headers(ids, 'employee'))).status_code == 409
    assert (await client.post(base + '/reopen', headers=headers(ids, 'finance_owner'))).status_code == 403
    admin = await client.post(base + '/reopen', headers=headers(ids))
    assert admin.status_code == (403 if visibility == 'private' else 200)
    if visibility == 'private':
        reopened = await client.post(base + '/reopen', headers=headers(ids, 'employee'))
    else:
        reopened = admin
    assert reopened.json()['status'] == 'active'
    assert reopened.json()['revision'] == completed_revision + 1
    assert reopened.json()['completed_at'] is None
    assert reopened.json()['started_at'] == completed.json()['started_at']
    assert (await client.post(base + '/reopen', headers=headers(ids, 'employee'))).status_code == 409
    assert (await client.patch(f"/api/v1/guided/answers/{saved['id']}", headers=headers(ids, 'employee'), json={'body': 'Corrected after reopening'})).status_code == 200
    revisions = await client.get(base + '/revisions', headers=headers(ids, 'employee'))
    assert 'Session reopened' in [item['summary']['change'] for item in revisions.json()]
    async with factory() as session:
        actions = list(await session.scalars(select(AuditEvent.action).where(AuditEvent.entity_id == UUID(guided['id']))))
        assert actions.count(AuditAction.GUIDED_SESSION_REOPENED.value) == 1
        assert AuditAction.GUIDED_SESSION_COMPLETED.value in actions
    assert (await client.post(base + '/complete', headers=headers(ids, 'employee'))).status_code == 200
    assert (await client.post(base + '/archive', headers=headers(ids, 'employee'))).status_code == 200
    assert (await client.post(base + '/reopen', headers=headers(ids, 'employee'))).status_code == 409
    assert (await client.patch(base, headers=headers(ids, 'employee'), json={'title': 'Archived edit'})).status_code == 409

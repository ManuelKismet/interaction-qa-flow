"""Opt-in synthetic observation probes. Passing reproduces known defects;
these are not security acceptance tests. Firebase verification is mocked,
while request identity dependencies, mapping and tenant checks remain real.
"""
from tests.conftest import app_client
from uuid import UUID
import re
import pytest
from sqlalchemy import select
from app.main import app
from app.api import dependencies
from app.api.dependencies import get_development_identity, enforce_tenant_scope
from app.models import FirebaseUidMapping, User
from app.models.question import Question, QuestionVisibility
from tests.test_answer_governance import seed_governance

async def setup_real_boundary(app_client, monkeypatch):
    client, factory = app_client
    ids = await seed_governance(factory)
    names = ['employee','finance_owner','people_owner','admin','outsider']
    async with factory() as session:
        for name in names:
            session.add(FirebaseUidMapping(firebase_uid='review-'+name,user_id=ids[name]))
        await session.commit()
    app.dependency_overrides.pop(get_development_identity,None)
    app.dependency_overrides.pop(enforce_tenant_scope,None)
    def verify(token, settings):
        assert token in names
        return {'aud':settings.firebase_project_id,'iss':'https://securetoken.google.com/'+settings.firebase_project_id,'sub':'review-'+token}
    monkeypatch.setattr(dependencies,'verify_id_token',verify)
    def headers(name):
        return {'Authorization':'Bearer '+name}
    return client,factory,ids,headers

@pytest.mark.asyncio
async def test_all_api_operations_require_identity(app_client):
    client,_=app_client
    app.dependency_overrides.pop(get_development_identity,None)
    app.dependency_overrides.pop(enforce_tenant_scope,None)
    checked=0
    for path,item in app.openapi()['paths'].items():
        if not path.startswith('/api/v1/'):
            continue
        path=re.sub(r'\{[^}]+\}',str(UUID(int=0)),path)
        for method in item:
            if method not in {'get','post','put','patch','delete'}:
                continue
            response=await client.request(method,path,json={} if method in {'post','put','patch'} else None)
            assert response.status_code==401,(method,path,response.status_code,response.text)
            checked+=1
    print('Unauthenticated API operation checks:',checked)

@pytest.mark.asyncio
async def test_known_privacy_findings_and_tenant_negatives(app_client,monkeypatch):
    client,factory,ids,h=await setup_real_boundary(app_client,monkeypatch)
    async with factory() as session:
        q=await session.get(Question,ids['finance_question'])
        q.visibility=QuestionVisibility.PRIVATE
        await session.commit()
    qid=str(ids['finance_question'])
    detail=await client.get('/api/v1/questions/'+qid,headers=h('people_owner'))
    listing=await client.get('/api/v1/questions',headers=h('people_owner'))
    answers=await client.get('/api/v1/questions/'+qid+'/answers',headers=h('people_owner'))
    comment=await client.post('/api/v1/questions/'+qid+'/comments',headers=h('people_owner'),json={'body':'Synthetic visibility probe'})
    assert detail.status_code==200,detail.text
    assert listing.status_code==200 and any(q['id']==qid for q in listing.json())
    assert answers.status_code==200 and len(answers.json())==2,answers.text
    assert comment.status_code==201,comment.text
    print('IQ-03 reproduced: private detail/list/answers=200, unrelated actor comment=201')
    outsider=await client.get('/api/v1/questions/'+qid,headers=h('outsider'))
    assert outsider.status_code==404,outsider.text
    forged=await client.get('/api/v1/questions',headers=h('employee'),params={'organisation_id':str(ids['other_organisation'])})
    assert forged.status_code==403,forged.text
    admin_action=await client.post('/api/v1/departments',headers=h('employee'),json={'name':'Synthetic restricted action'})
    assert admin_action.status_code==403,admin_action.text
    print('Tenant/role negatives: other-tenant ID=404, forged organisation=403, employee admin action=403')
    async with factory() as session:
        for name in ['employee','people_owner']:
            user=await session.get(User,ids[name]); user.department_id=None
        await session.commit()
    created=await client.post('/api/v1/guided/sessions',headers=h('employee'),json={'title':'Synthetic null department probe','visibility':'department'})
    assert created.status_code==201,created.text
    read=await client.get('/api/v1/guided/sessions/'+created.json()['id'],headers=h('people_owner'))
    assert read.status_code==200,read.text
    print('IQ-04 reproduced: null-department session creation=201; unrelated departmentless actor read=200')
    private=await client.post('/api/v1/guided/sessions',headers=h('employee'),json={'title':'Synthetic private admin policy probe','visibility':'private'})
    assert private.status_code==201,private.text
    admin_read=await client.get('/api/v1/guided/sessions/'+private.json()['id'],headers=h('admin'))
    assert admin_read.status_code==200,admin_read.text
    print('IQ-05 policy discrepancy reproduced: admin private-session read=200')

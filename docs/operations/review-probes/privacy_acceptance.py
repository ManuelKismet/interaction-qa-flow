from tests.conftest import app_client
from backend_security_observations import setup_real_boundary, test_all_api_operations_require_identity
import pytest
from app.models.question import Question, QuestionVisibility
from app.models.guided import GuidedSession, GuidedSessionVisibility
from app.models.user import User

@pytest.mark.asyncio
async def test_private_knowledge_through_uid_boundary(app_client,monkeypatch):
 c,f,ids,h=await setup_real_boundary(app_client,monkeypatch)
 async with f() as s:
  q=await s.get(Question,ids['finance_question']);q.visibility=QuestionVisibility.PRIVATE
  await s.commit()
 qid=str(ids['finance_question']);base='/api/v1/questions/'+qid
 for suffix in ['', '/answers','/comments','/duplicate-candidates']:
  response=await c.get(base+suffix,headers=h('people_owner'));assert response.status_code==403,response.text
 for suffix in ['/answers','/comments']:
  response=await c.post(base+suffix,headers=h('people_owner'),json={'body':'Denied synthetic mutation'});assert response.status_code==403,response.text
 listing=await c.get('/api/v1/questions',headers=h('people_owner'));assert listing.status_code==200
 assert all(q['id']!=qid for q in listing.json())
 for suffix in ['', '/answers']:
  response=await c.get(base+suffix,headers=h('employee'));assert response.status_code==200,response.text
 outsider=await c.get(base,headers=h('outsider'));assert outsider.status_code==404,outsider.text
 forged=await c.get('/api/v1/questions',headers=h('employee'),params={'organisation_id':str(ids['other_organisation'])});assert forged.status_code==403
 print('IQ-03 real UID boundary: denied unrelated reads/writes/list; owner allowed; other tenant denied')

@pytest.mark.asyncio
async def test_department_interact_through_uid_boundary(app_client,monkeypatch):
 c,f,ids,h=await setup_real_boundary(app_client,monkeypatch)
 missing=await c.post('/api/v1/guided/sessions',headers=h('employee'),json={'title':'Missing department','visibility':'department'});assert missing.status_code==409,missing.text
 async with f() as s:
  for name in ['employee','people_owner']:
   u=await s.get(User,ids[name]);u.department_id=None
  legacy=GuidedSession(organisation_id=ids['organisation'],created_by=ids['employee'],title='Synthetic legacy null department',visibility=GuidedSessionVisibility.DEPARTMENT,department_id=None)
  s.add(legacy);await s.commit();sid=str(legacy.id)
 base='/api/v1/guided/sessions/'+sid
 for suffix in ['', '/revisions','/export/json','/export/csv']:
  response=await c.get(base+suffix,headers=h('people_owner'));assert response.status_code==403,response.text
 owner=await c.get(base,headers=h('employee'));assert owner.status_code==200,owner.text
 listing=await c.get('/api/v1/guided/sessions',headers=h('people_owner'));assert listing.status_code==200
 assert all(x['id']!=sid for x in listing.json())
 print('IQ-04 real UID boundary: missing department rejected; legacy null-match reads/exports denied; owner allowed')

@pytest.mark.asyncio
async def test_private_admin_owner_only_acceptance(app_client,monkeypatch):
 c,f,ids,h=await setup_real_boundary(app_client,monkeypatch)
 created=await c.post('/api/v1/guided/sessions',headers=h('employee'),json={'title':'Synthetic private administrator probe','visibility':'private'});assert created.status_code==201
 response=await c.get('/api/v1/guided/sessions/'+created.json()['id'],headers=h('admin'));assert response.status_code==403,response.text
 print('IQ-05 owner-only: administrator denied through real UID boundary')

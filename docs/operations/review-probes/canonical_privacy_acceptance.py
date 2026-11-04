from tests.conftest import app_client
from backend_security_observations import setup_real_boundary
from app.models.question import Question,QuestionVisibility
import pytest

@pytest.mark.asyncio
async def test_public_alias_cannot_disclose_private_canonical_target(app_client,monkeypatch):
 c,f,ids,h=await setup_real_boundary(app_client,monkeypatch)
 async with f() as s:
  root=await s.get(Question,ids['finance_question']);root.visibility=QuestionVisibility.PRIVATE
  alias=Question(organisation_id=ids['organisation'],author_id=ids['employee'],title='Synthetic public alias',visibility=QuestionVisibility.ORGANISATION,canonical_question_id=root.id)
  source=Question(organisation_id=ids['organisation'],author_id=ids['employee'],title='Synthetic visible suggestion source',visibility=QuestionVisibility.ORGANISATION)
  s.add_all([alias,source]);await s.commit();aid=str(alias.id);sid=str(source.id)
 response=await c.post('/api/v1/questions/'+sid+'/duplicate-suggestions',headers=h('people_owner'),json={'suggested_canonical_question_id':aid,'reason':'Synthetic private canonical boundary probe'})
 print('CANONICAL TARGET RESPONSE',response.status_code,response.text)
 assert response.status_code==403

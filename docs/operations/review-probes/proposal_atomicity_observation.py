# Historical DEFECT observation on a67a246, not an acceptance test.
# Run explicitly with PYTHONPATH set to reviewed backend and EMBEDDING_PROVIDER=fake.
# All data lives in the app_client in-memory SQLite fixture, never hosted/legacy DB.
from uuid import UUID
import pytest
from sqlalchemy import select,func
from tests.conftest import app_client
from tests.test_guided import create_session,add_participant,add_question,answer
from tests.test_answer_governance import headers,seed_governance
from app.models.question import Question
from app.models.guided import KnowledgeProposal
from app.services.answer import AnswerService

@pytest.mark.asyncio
async def test_observe_partial_commit_and_retry(app_client,monkeypatch):
    client,factory=app_client
    ids=await seed_governance(factory)
    guided=await create_session(client,ids,title='E2E isolated atomicity')
    p=await add_participant(client,ids,guided['id'],'Synthetic')
    q=await add_question(client,ids,guided['id'],'E2E isolated proposal rollback marker')
    a=await answer(client,ids,q['id'],p['id'],'Synthetic answer')
    proposed=await client.post('/api/v1/guided/knowledge-proposals',headers=headers(ids,'employee'),json={'guided_question_id':q['id'],'guided_answer_id':a['id']})
    assert proposed.status_code==201
    proposal_id=proposed.json()['id']
    async def fail(self,*args,**kwargs):raise RuntimeError('E2E synthetic answer persistence failure')
    original=AnswerService.create
    monkeypatch.setattr(AnswerService,'create',fail)
    with pytest.raises(RuntimeError,match='E2E synthetic'):
        await client.post('/api/v1/guided/knowledge-proposals/'+proposal_id,headers=headers(ids),json={'action':'accept'})
    async with factory() as s:
        count=await s.scalar(select(func.count()).select_from(Question).where(Question.title=='E2E isolated proposal rollback marker'))
        state=await s.scalar(select(KnowledgeProposal).where(KnowledgeProposal.id==UUID(proposal_id)))
        print('AFTER_FAILURE_QUESTION_COUNT',count,'PROPOSAL_STATE',state.status.value,'CREATED_QUESTION_LINK',state.created_question_id)
        assert count==1 and state.status.value=='pending'
    monkeypatch.setattr(AnswerService,'create',original)
    retried=await client.post('/api/v1/guided/knowledge-proposals/'+proposal_id,headers=headers(ids),json={'action':'accept'})
    assert retried.status_code==200,retried.text
    async with factory() as s:
        count=await s.scalar(select(func.count()).select_from(Question).where(Question.title=='E2E isolated proposal rollback marker'))
        print('AFTER_RETRY_QUESTION_COUNT',count)
        assert count==2

import pytest
from app.ai.embedding_provider import DeterministicFakeEmbeddingProvider, EmbeddingProviderError
from app.core.config import Settings
from app.models.organisation import Organisation
from app.models.user import User
from app.models.question import Question,QuestionStatus
from app.models.answer import Answer,AnswerStatus
from app.services.search import SearchService
class BrokenProvider(DeterministicFakeEmbeddingProvider):
 async def embed_text(self,text):raise EmbeddingProviderError('synthetic failure')
@pytest.mark.asyncio
async def test_answer_fanout_does_not_hide_other_canonical_matches(app_client):
 _,sf=app_client
 async with sf() as s:
  o=Organisation(name='Independent fanout',slug='independent-fanout');s.add(o);await s.flush()
  u=User(organisation_id=o.id,email='fanout@example.invalid',display_name='Synthetic');s.add(u);await s.flush()
  a=Question(organisation_id=o.id,author_id=u.id,title='password',status=QuestionStatus.ANSWERED)
  b=Question(organisation_id=o.id,author_id=u.id,title='password rotation policy',status=QuestionStatus.ANSWERED)
  s.add_all([a,b]);await s.flush()
  for n in range(60):s.add(Answer(organisation_id=o.id,question_id=a.id,author_id=u.id,body='Synthetic answer '+str(n),status=AnswerStatus.COMMUNITY))
  s.add(Answer(organisation_id=o.id,question_id=b.id,author_id=u.id,body='Synthetic policy answer',status=AnswerStatus.COMMUNITY));await s.commit()
  results=await SearchService(s,BrokenProvider(),Settings()).search(query='password',limit=5,organisation_id=o.id,user_id=u.id)
  assert {x.question_id for x in results}=={a.id,b.id},'Repeated answer rows consumed the candidate limit before canonical collapse'

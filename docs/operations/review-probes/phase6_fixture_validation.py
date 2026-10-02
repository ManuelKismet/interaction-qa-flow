from pathlib import Path
import json,pytest
from tests.conftest import app_client
from backend_security_observations import setup_real_boundary
@pytest.mark.asyncio
async def test_prepared_phase6_fixture(app_client,monkeypatch):
 c,f,ids,h=await setup_real_boundary(app_client,monkeypatch)
 fixture=json.loads((Path(__file__).resolve().parent.parent/'acceptance-fixtures/phase6-legacy-session.json').read_text())
 response=await c.post('/api/v1/guided/import/legacy',headers=h('employee'),json={'payload':fixture})
 assert response.status_code==200,response.text
 data=response.json();assert data['warnings']==[]
 root=data['session']['questions'][0]
 assert {a['body'] for a in root['answers']}=={'Email','Phone'}
 first=root['follow_ups'][0];assert first['text']=='Who sent it?'
 assert first['follow_ups'][0]['text']=='Next synthetic step?'
 for output in ['json','csv']:
  exported=await c.get('/api/v1/guided/sessions/'+data['session']['id']+'/export/'+output,headers=h('employee'))
  assert exported.status_code==200,exported.text
  assert 'Synthetic nested answer' in exported.text
 print('Two-participant nested Phase 6 import and JSON/CSV exports verified synthetically')

import gzip, hashlib, json, subprocess, sys
from pathlib import Path
import httpx
root=Path(sys.argv[1]).resolve()
if not (root/'index.html').is_file(): raise SystemExit('Missing Flutter index.html')
g=str(Path.home()/'.local/share/intqaflow/gcloud/google-cloud-sdk/bin/gcloud')
token=subprocess.check_output([g,'auth','print-access-token'],text=True).strip()
client=httpx.Client(headers={'Authorization':'Bearer '+token,'X-Goog-User-Project':'intqaflow-dev'},timeout=90)
base='https://firebasehosting.googleapis.com/v1beta1/'
def request(method,url,**kwargs):
 r=client.request(method,url,**kwargs)
 if not r.is_success: raise RuntimeError('Hosting API HTTP '+str(r.status_code))
 return r.json() if r.content and 'application/json' in r.headers.get('content-type','') else {}
version=request('POST',base+'sites/intqaflow-dev/versions',json={'config':{'rewrites':[{'glob':'**','path':'/index.html'}],'headers':[{'glob':'**','headers':{'Cache-Control':'max-age=300'}}]}})['name']
files={}; blobs={}
for p in sorted(root.rglob('*')):
 if not p.is_file() or any(part.startswith('.') for part in p.relative_to(root).parts): continue
 data=gzip.compress(p.read_bytes(),mtime=0);h=hashlib.sha256(data).hexdigest();files['/'+p.relative_to(root).as_posix()]=h;blobs[h]=data
items=list(files.items())
for start in range(0,len(items),1000):
 result=request('POST',base+version+':populateFiles',json={'files':dict(items[start:start+1000])})
 for h in result.get('uploadRequiredHashes',[]):
  request('POST',result['uploadUrl']+'/'+h,content=blobs[h],headers={'Content-Type':'application/octet-stream'})
request('PATCH',base+version+'?update_mask=status',json={'status':'FINALIZED'})
release=request('POST',base+'sites/intqaflow-dev/releases',params={'versionName':version})
print('HOSTING_RELEASE',release['name'],'FILES',len(files),'VERSION',version,flush=True)

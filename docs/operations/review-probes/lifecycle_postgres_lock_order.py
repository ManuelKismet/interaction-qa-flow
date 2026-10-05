import getpass, os, secrets, subprocess, tempfile
from pathlib import Path
from sqlalchemy.engine import URL
root=Path('/home/vscode/.local/share/intqaflow')
pg=Path('/usr/lib/postgresql/16/bin')
work=Path(tempfile.mkdtemp(prefix='e2e-pg-',dir=root))
password=secrets.token_urlsafe(32)
pw=work/'password'
pw.write_text(password)
pw.chmod(0o600)
env=os.environ.copy()
env['POSTGRES_TEST_DATABASE_URL']=URL.create('postgresql+asyncpg',username=getpass.getuser(),password=password,host='127.0.0.1',port=55441,database='postgres').render_as_string(hide_password=False)
started=False
try:
    with open(root/'review-05092fb-migration-postgres-setup.log','w') as log:
        subprocess.run([str(pg/'initdb'),'-D',str(work/'data'),'--auth-local=trust','--auth-host=scram-sha-256','--pwfile',str(pw)],stdout=log,stderr=log,check=True)
        subprocess.run([str(pg/'pg_ctl'),'-D',str(work/'data'),'-l',str(work/'server.log'),'-o','-h 127.0.0.1 -p 55441 -k '+str(work),'-w','start'],stdout=log,stderr=log,check=True)
        started=True
        subprocess.run([str(pg/"psql"),"-h",str(work),"-p","55441","-d","postgres","-c","CREATE EXTENSION vector"],stdout=log,stderr=log,check=True)
    import asyncpg, asyncio
    from uuid import uuid4
    env['DATABASE_URL']=env['POSTGRES_TEST_DATABASE_URL'].replace('postgresql+psycopg','postgresql+asyncpg')
    python='/workspaces/intqaflow/backend/.venv/bin/python'
    cwd='/workspaces/intqaflow-review-pr13-58e199f/backend'
    def migrate(direction,target):
        with open(root/'review-05092fb-migration-alembic.log','a') as log:
            subprocess.run([python,'-m','alembic',direction,target],cwd=cwd,env=env,stdout=log,stderr=log,check=True)
    class Result:
        def __init__(self,rows): self.rows=rows
        def fetchone(self): return tuple(self.rows[0]) if self.rows else None
    class Connection:
        def __enter__(self): return self
        def __exit__(self,*args): pass
        def execute(self,sql,params=()):
            for index in range(len(params)): sql=sql.replace('%s','$'+str(index+1),1)
            async def run():
                c=await asyncpg.connect(host='127.0.0.1',port=55441,user=getpass.getuser(),password=password,database='postgres')
                try: return Result(await c.fetch(sql,*params))
                finally: await c.close()
            return asyncio.run(run())
    def connect(): return Connection()
    migrate('upgrade','0011')
    gid,mid=uuid4(),uuid4()
    with connect() as c:
        c.execute("INSERT INTO guest_groups(id,name,created_by_uid,expires_at) VALUES(%s,'Migration legacy group','legacy-admin',now()+interval '90 days')",(gid,))
        c.execute("INSERT INTO guest_group_memberships(id,group_id,firebase_uid,display_name,role,status) VALUES(%s,%s,'legacy-admin','Legacy admin','admin','active')",(mid,gid))
    migrate('upgrade','head')
    with connect() as c:
        assert c.execute('SELECT archived_at,archived_by_uid FROM guest_groups WHERE id=%s',(gid,)).fetchone()==(None,None)
        assert c.execute('SELECT version_num FROM alembic_version').fetchone()[0]=='0012'
        c.execute("INSERT INTO guest_group_admin_transfers(id,group_id,requested_by_uid,target_membership_id,status,expires_at) VALUES(%s,%s,'legacy-admin',%s,'pending',now()+interval '7 days')",(uuid4(),gid,mid))
    try:
        with connect() as c:
            c.execute("INSERT INTO guest_group_admin_transfers(id,group_id,requested_by_uid,target_membership_id,status,expires_at) VALUES(%s,%s,'legacy-admin',%s,'pending',now()+interval '7 days')",(uuid4(),gid,mid))
        raise AssertionError('Second pending transfer allowed')
    except asyncpg.UniqueViolationError:
        print('PENDING_TRANSFER_UNIQUE_INDEX_PASS',flush=True)
    migrate('downgrade','0011')
    with connect() as c:
        assert c.execute('SELECT count(*) FROM guest_groups WHERE id=%s',(gid,)).fetchone()[0]==1
        assert c.execute('SELECT count(*) FROM guest_group_memberships WHERE id=%s',(mid,)).fetchone()[0]==1
    migrate('upgrade','head')
    with connect() as c:
        assert c.execute('SELECT version_num FROM alembic_version').fetchone()[0]=='0012'
        assert c.execute('SELECT count(*) FROM guest_groups WHERE id=%s',(gid,)).fetchone()[0]==1
    print('POSTGRES_FULL_CHAIN_0011_0012_DOWN_UP_LEGACY_PRESERVED_PASS',flush=True)
    import sys
    sys.path.insert(0,cwd)
    from fastapi import HTTPException
    from sqlalchemy import select
    from sqlalchemy.ext.asyncio import create_async_engine,async_sessionmaker
    from app.services.guest import GuestService
    from app.models.guest import GuestGroup,GuestGroupMembership,GuestGroupAdminTransfer
    from app.schemas.guest import GuestGroupCreate
    async def races():
        engine=create_async_engine(env['DATABASE_URL'])
        sessions=async_sessionmaker(engine,expire_on_commit=False)
        async def invoke(method,*args,**kwargs):
            async with sessions() as session:
                try:
                    result=await getattr(GuestService(session),method)(*args,**kwargs)
                    return 200,result
                except HTTPException as error:
                    await session.rollback()
                    return error.status_code,None
        try:
            for kind in []:
                for iteration in range(3):
                    owner='race-owner-'+uuid4().hex
                    target_uid='race-target-'+uuid4().hex
                    code,group=await invoke('create_group',owner,GuestGroupCreate(name='Disposable race',display_name='Owner'))
                    assert code==200
                    group_id=group['id']
                    async with sessions() as session:
                        target=GuestGroupMembership(group_id=group_id,firebase_uid=target_uid,display_name='Target',role='contributor',status='active')
                        session.add(target);await session.commit();target_id=target.id
                    if kind=='double_propose':
                        results=await asyncio.wait_for(asyncio.gather(invoke('transfer_administration',group_id,target_id,owner),invoke('transfer_administration',group_id,target_id,owner)),10)
                        assert sorted(x[0] for x in results)==[200,409],results
                    else:
                        code,proposal=await invoke('transfer_administration',group_id,target_id,owner)
                        assert code==200
                        accept=lambda:invoke('respond_admin_transfer',group_id,proposal['id'],target_uid,accept=True)
                        other=accept if kind=='double_accept' else lambda:invoke('remove_member',group_id,target_id,owner) if kind=='remove_accept' else invoke('archive_group',group_id,owner)
                        results=await asyncio.wait_for(asyncio.gather(accept(),other()),10)
                        if kind=='double_accept':assert sorted(x[0] for x in results)==[200,404],results
                        else:assert sorted(x[0] for x in results) in ([200,403],[200,404]),results
                    async with sessions() as session:
                        members=list(await session.scalars(select(GuestGroupMembership).where(GuestGroupMembership.group_id==group_id)))
                        assert sum(m.role=='admin' and m.status=='active' for m in members)==1
                        pending=list(await session.scalars(select(GuestGroupAdminTransfer).where(GuestGroupAdminTransfer.group_id==group_id,GuestGroupAdminTransfer.status=='pending')))
                        assert len(pending)<=1
                print('POSTGRES_CONCURRENT_'+kind.upper()+'_PASS_3',flush=True)
            owner='lock-order-owner-'+uuid4().hex
            code,group=await invoke('create_group',owner,GuestGroupCreate(name='Disposable lock order',display_name='Owner'))
            group_id=group['id']
            group_held=asyncio.Event();rate_held=asyncio.Event()
            from app.schemas.guest import GuestInvitationCreate
            from sqlalchemy.exc import DBAPIError
            async def create_invite():
                async with sessions() as session:
                    service=GuestService(session);original=service._group
                    async def paused_group(*args,**kwargs):
                        result=await original(*args,**kwargs)
                        await session.flush();group_held.set();await rate_held.wait();return result
                    service._group=paused_group
                    try:
                        await service.list_invitations(group_id,owner)
                        return 'success'
                    except DBAPIError as error:
                        await session.rollback()
                        return getattr(error.orig,'sqlstate',None) or getattr(getattr(error.orig,'__cause__',None),'sqlstate',None) or type(error.orig).__name__
            async def archive():
                async with sessions() as session:
                    service=GuestService(session);original=service._rate_limit
                    async def paused_rate(*args,**kwargs):
                        await original(*args,**kwargs)
                        rate_held.set();await group_held.wait()
                    service._rate_limit=paused_rate
                    try:
                        await service.list_groups(owner)
                        return 'success'
                    except DBAPIError as error:
                        await session.rollback()
                        return getattr(error.orig,'sqlstate',None) or getattr(getattr(error.orig,'__cause__',None),'sqlstate',None) or type(error.orig).__name__
            outcomes=await asyncio.wait_for(asyncio.gather(create_invite(),archive()),10)
            print('INVITATION_LIST_GROUP_LIST_LOCK_ORDER_OUTCOMES',outcomes,flush=True)
            assert '40P01' in outcomes,outcomes
            print('INVITATION_LIST_GROUP_LIST_DEADLOCK_REPRODUCED',flush=True)
        finally:await engine.dispose()
    asyncio.run(races())

finally:
    if started:
        subprocess.run([str(pg/'pg_ctl'),'-D',str(work/'data'),'-m','fast','-w','stop'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=True)
    pw.unlink(missing_ok=True)
    print('FRESH_POSTGRES_STOPPED',started,flush=True)

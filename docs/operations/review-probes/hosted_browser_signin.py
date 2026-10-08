import asyncio,json,os
from pathlib import Path
from playwright.async_api import async_playwright
async def main():
 result={'stage':'launch','checks':{}};browser=None
 try:
  async with async_playwright() as p:
   browser=await p.chromium.launch(headless=True)
   page=await browser.new_page(viewport={'width':1365,'height':900})
   events=[]
   def response(r):
    if '/api/v1/auth/me' in r.url: events.append({'kind':'membership','status':r.status})
    if 'exchangeRecaptchaEnterpriseToken' in r.url: events.append({'kind':'appcheck_exchange','status':r.status})
   page.on('response',response)
   result['stage']='load'
   await page.goto('https://intqaflow-dev.web.app/',wait_until='domcontentloaded')
   await page.locator('flt-semantics-placeholder').wait_for(timeout=60000)
   await page.locator('flt-semantics-placeholder').evaluate('(el)=>el.click()')
   await page.get_by_role('textbox',name='Email',exact=True).wait_for(timeout=30000)
   result['checks']['signin_form']=True
   creds=json.loads((Path.home()/'.local/share/intqaflow/synthetic-dev-browser-user.json').read_text())
   result['stage']='signin'
   await page.get_by_role('textbox',name='Email',exact=True).fill(creds['email'])
   await page.get_by_role('textbox',name='Password',exact=True).fill(creds['password'])
   await page.get_by_role('button',name='Sign in',exact=True).click()
   await page.get_by_text('IntQAFlow Knowledge',exact=False).first.wait_for(timeout=60000)
   result['checks']['browser_signin']=True
   result['stage']='signed_in'
   result['ui']=await page.locator('body').inner_text()
   result['events']=events
   await page.screenshot(path='/tmp/intqaflow-browser-signed-in.png')
   await browser.close()
 except Exception as e:
  result['error_type']=type(e).__name__
  result['events']=locals().get('events',[])
 finally:
  Path('/tmp/intqaflow-browser-signin-result.json').write_text(json.dumps(result,indent=2))
  print(json.dumps(result),flush=True)
asyncio.run(main())

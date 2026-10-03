"""Sequential hosted-dev viewport review. No account creation or cloud sharing."""
import argparse, json, time
from pathlib import Path
from playwright.sync_api import sync_playwright
parser=argparse.ArgumentParser()
parser.add_argument("--output",required=True)
args=parser.parse_args()
out=Path(args.output); out.mkdir(parents=True,exist_ok=True)
results=[]
with sync_playwright() as p:
    browser=p.chromium.launch(headless=True)
    for name,w,h in [("phone390",390,844),("phone360",360,800),("ipadportrait",820,1180),("ipadlandscape",1180,820)]:
        ctx=browser.new_context(viewport={"width":w,"height":h},device_scale_factor=1,locale="en-GB")
        page=ctx.new_page()
        row={"viewport":name,"width":w,"height":h,"views":[],"errors":[]}
        page.on("pageerror",lambda e, r=row: r["errors"].append(str(e)[:300]))
        def enter(locator, value):
            locator.click(); page.keyboard.press("Control+A"); page.keyboard.type(value,delay=35)
            page.wait_for_timeout(1000)
        def capture(view):
            page.screenshot(path=str(out/f"{name}-{view}.png"))
            row["views"].append({"view":view,"geometry":page.evaluate("({width:innerWidth,height:innerHeight,scrollWidth:document.documentElement.scrollWidth})")})
        try:
            page.goto("https://intqaflow-dev.web.app/",wait_until="domcontentloaded",timeout=60000)
            placeholder=page.locator("flt-semantics-placeholder")
            placeholder.wait_for(state="attached",timeout=60000)
            placeholder.evaluate("(el)=>el.click()")
            page.get_by_role("tab",name="Knowledge",exact=True).wait_for(timeout=30000)
            page.wait_for_timeout(800)
            capture("knowledge")
            page.get_by_role("tab",name="Interact",exact=True).click()
            page.get_by_role("button",name="Create session locally",exact=True).wait_for()
            page.wait_for_timeout(500); capture("interact-empty")
            enter(page.get_by_role("textbox",name="New Interact session",exact=True),"Responsive UI review")
            page.get_by_role("button",name="Create session locally",exact=True).click()
            session=page.get_by_role("button",name="Responsive UI review 1 participants · Private on this device",exact=True)
            session.wait_for()
            session.click()
            enter(page.get_by_role("textbox",name="Prepared question",exact=True),"How does this layout handle a longer prepared question on a small screen?")
            page.wait_for_timeout(800)
            page.get_by_role("button",name="Add shared question",exact=True).click()
            page.wait_for_timeout(800)
            for _ in range(5):
                if page.get_by_role("textbox",name="Local answer",exact=True).count(): break
                page.mouse.wheel(0,300); page.wait_for_timeout(400)
            answer=page.get_by_role("textbox",name="Local answer",exact=True)
            enter(answer.first,"Local layout sample only. This content is not uploaded or shared.")
            enter(page.get_by_role("textbox",name="Follow-up question",exact=True).first,"Can the participant see the parent answer and follow-up context?")
            page.wait_for_timeout(800)
            page.get_by_role("button",name="Add answer-owned follow-up",exact=True).first.click()
            page.wait_for_timeout(800)
            page.wait_for_timeout(500); capture("interact-editor")
            page.get_by_role("button",name="Download / Share PDF",exact=True).click()
            page.get_by_role("button",name="Selected participant",exact=True).click()
            page.get_by_role("button",name="Download PDF",exact=True).wait_for()
            page.wait_for_timeout(500); capture("pdf-preview")
            row["preview_buttons"]=page.get_by_role("button").all_text_contents()
            page.mouse.click(5,h//2); page.wait_for_timeout(500)
            row["outside_click_dismissed"]=not page.get_by_role("button",name="Download PDF",exact=True).count()
            if not row["outside_click_dismissed"]: page.keyboard.press("Escape")
            page.get_by_role("button",name="Download / Share PDF",exact=True).wait_for()
            row["escape_or_outside_returned"]=True
            page.get_by_role("button",name="Save as local template",exact=True).click()
            page.wait_for_timeout(500); capture("template-dialog")
            row["template_dialog_text"]=page.locator("body").inner_text()[-3500:]
            page.keyboard.press("Escape")
            page.get_by_role("button",name="Account",exact=True).click()
            page.wait_for_timeout(500); capture("account-menu")
            row["account_menu_text"]=page.locator("body").inner_text()[-3500:]
            page.get_by_role("menuitem",name="Sign in",exact=True).click()
            page.wait_for_timeout(500); capture("sign-in")
            row["signin_text"]=page.locator("body").inner_text()[-3500:]
            row["signin_buttons"]=page.get_by_role("button").all_text_contents()
            page.get_by_role("button",name="Create account or link guest recovery",exact=True).click()
            page.wait_for_timeout(500); capture("sign-up")
            row["signup_text"]=page.locator("body").inner_text()[-3500:]
            row["signup_buttons"]=page.get_by_role("button").all_text_contents()
        except Exception as e:
            row["blocked"]=str(e)[:800]
            capture("blocked")
        finally:
            results.append(row)
            ctx.close()
            (out/"results.json").write_text(json.dumps(results,indent=2))
    browser.close()
(out/"index.html").write_text("<html><body><h1>IntQAFlow viewport review</h1>"+ "".join(f"<h2>{f.name}</h2><img style='max-width:100%;border:1px solid #999' src='{f.name}'>" for f in sorted(out.glob("*.png")))+"</body></html>")
print(json.dumps(results,indent=2))

"""Private Codespace interactive review. Forward 8767 privately; never expose VNC."""
import os, signal, subprocess, time
from pathlib import Path
from playwright.sync_api import sync_playwright
root=Path.home()/".local/share/intqaflow/responsive-browser"
root.mkdir(parents=True,exist_ok=True)
children=[]
log=open(root/"interactive-services.log","a")
try:
    children.append(subprocess.Popen(["Xvfb",":97","-screen","0","1280x960x24","-nolisten","tcp"],stdout=log,stderr=log))
    for _ in range(40):
        if Path("/tmp/.X11-unix/X97").exists(): break
        time.sleep(.25)
    else: raise RuntimeError("Virtual display did not start")
    children.append(subprocess.Popen(["x11vnc","-display",":97","-localhost","-rfbport","5997","-nopw","-forever","-shared"],stdout=log,stderr=log))
    children.append(subprocess.Popen(["websockify","--web=/usr/share/novnc","127.0.0.1:8767","127.0.0.1:5997"],stdout=log,stderr=log))
    os.environ["DISPLAY"]=":97"
    with sync_playwright() as p:
        ctx=p.chromium.launch_persistent_context(str(root/"interactive-profile"),headless=False,viewport=None,locale="en-GB",args=["--window-size=1180,900","--window-position=0,0","--disable-gpu","--use-angle=swiftshader"])
        page=ctx.pages[0]
        page.goto("https://intqaflow-dev.web.app/",wait_until="domcontentloaded")
        print("Interactive Chromium ready; VNC loopback only; forward 8767 privately.",flush=True)
        while ctx.pages:
            page.wait_for_timeout(1000)
finally:
    for proc in reversed(children):
        proc.terminate()
    log.close()

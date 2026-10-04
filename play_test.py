"""Brief playtest via the persistent MCP proxy: start play, capture console, stop."""
import json, sys, subprocess, threading, queue, time, glob, os

EXE = glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\StudioMCP.exe"))[0]
proc = subprocess.Popen([EXE], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE, text=True, encoding="utf-8", bufsize=1)
q = queue.Queue()
def reader():
    for line in proc.stdout:
        line=line.strip()
        if line:
            try: q.put(json.loads(line))
            except Exception: q.put({"_raw":line})
threading.Thread(target=reader, daemon=True).start()
_id=[1]
def send(method, params=None, notif=False):
    m={"jsonrpc":"2.0","method":method}
    if not notif: m["id"]=_id[0]; _id[0]+=1
    if params is not None: m["params"]=params
    proc.stdin.write(json.dumps(m)+"\n"); proc.stdin.flush(); return m.get("id")
def wait(i,t):
    e=time.time()+t
    while time.time()<e:
        try: m=q.get(timeout=0.2)
        except queue.Empty: continue
        if m.get("id")==i: return m
    return None
def call(n,a,t=30): return wait(send("tools/call",{"name":n,"arguments":a}),t)
def text(r):
    if not r: return None
    rr=r.get("result",r)
    if isinstance(rr,dict) and "content" in rr:
        return " ".join(c.get("text","") for c in rr["content"] if isinstance(c,dict))
    return json.dumps(rr)

send("initialize",{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"play","version":"1"}})
wait(1,15); send("notifications/initialized",notif=True)
# wait for Studio
for _ in range(20):
    r=call("get_studio_state",{},8); t=text(r) or ""
    if r and not r.get("result",{}).get("isError") and "Not connected" not in t and "Unable to find" not in t:
        print("CONNECTED:", t[:200]); break
    time.sleep(3)
st=call("list_roblox_studios",{},10); print("studios:", text(st))
import re
m=re.search(r'"id"\s*:\s*"([^"]+)"', text(st) or "")
if m: call("set_active_studio",{"studio_id":m.group(1)},10)

print("\n-- clearing console, then starting play --")
call("get_console_output",{},10)  # flush
print("start:", text(call("start_stop_play",{"is_start":True},30)))
time.sleep(7)
print("\n-- console during play --")
print((text(call("get_console_output",{},15)) or "(none)")[:2500])
print("\nstop:", text(call("start_stop_play",{"is_start":False},30)))
proc.terminate(); print("\nDONE")

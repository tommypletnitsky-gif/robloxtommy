"""Connect to the persistent Studio MCP proxy and run one Luau file; print its returned value.
Usage: python run_lua.py <file.lua>
"""
import json, sys, subprocess, threading, queue, time, glob, os, re

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
def call(n,a,t=60): return wait(send("tools/call",{"name":n,"arguments":a}),t)
def text(r):
    if not r: return None
    rr=r.get("result",r)
    if isinstance(rr,dict) and "content" in rr:
        return " ".join(c.get("text","") for c in rr["content"] if isinstance(c,dict))
    return json.dumps(rr)

send("initialize",{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"runlua","version":"1"}})
wait(1,15); send("notifications/initialized",notif=True)
for _ in range(20):
    r=call("get_studio_state",{},8); t=text(r) or ""
    if r and not r.get("result",{}).get("isError") and "Not connected" not in t and "Unable to find" not in t:
        break
    time.sleep(3)
else:
    print("ERROR: Studio never connected"); proc.terminate(); sys.exit(2)
st=text(call("list_roblox_studios",{},10)) or ""
m=re.search(r'"id"\s*:\s*"([^"]+)"', st)
if m: call("set_active_studio",{"studio_id":m.group(1)},10)

code=open(sys.argv[1],"r",encoding="utf-8").read()
out=None
for _ in range(8):
    r=call("execute_luau",{"code":code,"datamodel_type":"Edit"},90)
    out=text(r) or "(nil)"
    if not any(x in out for x in ("disconnected","doesn't have a place","Not connected","Unable to find")):
        break
    time.sleep(4)
print(out)
proc.terminate()

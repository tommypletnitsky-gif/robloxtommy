"""Persistent Roblox Studio MCP proxy driver.

Keeps ONE StudioMCP.exe alive so Studio (which connects OUT to localhost:13469)
can latch on, then waits for the connection, runs the build, reads console output.
"""
import json, sys, subprocess, threading, queue, time, glob, os, socket

EXE = glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\StudioMCP.exe"))[0]
print("proxy:", EXE)

proc = subprocess.Popen([EXE], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE, text=True, encoding="utf-8", bufsize=1)
q = queue.Queue()
def reader():
    for line in proc.stdout:
        line = line.strip()
        if line:
            try: q.put(json.loads(line))
            except Exception: q.put({"_raw": line})
threading.Thread(target=reader, daemon=True).start()

_id = [1]
def send(method, params=None, notif=False):
    msg = {"jsonrpc":"2.0","method":method}
    if not notif:
        msg["id"] = _id[0]; _id[0]+=1
    if params is not None:
        msg["params"] = params
    proc.stdin.write(json.dumps(msg)+"\n"); proc.stdin.flush()
    return msg.get("id")

def wait(i, t):
    end=time.time()+t
    while time.time()<end:
        try: m=q.get(timeout=0.2)
        except queue.Empty: continue
        if m.get("id")==i: return m
    return None

def call(name, args, t=60):
    i = send("tools/call", {"name":name,"arguments":args})
    return wait(i, t)

def text_of(resp):
    if not resp: return None
    r = resp.get("result", resp)
    if isinstance(r, dict) and "content" in r:
        return " ".join(c.get("text","") for c in r["content"] if isinstance(c,dict))
    return json.dumps(r)

def port_open(p):
    s=socket.socket(); s.settimeout(0.3)
    try: s.connect(("127.0.0.1",p)); s.close(); return True
    except Exception: return False

# handshake
i = send("initialize", {"protocolVersion":"2024-11-05","capabilities":{},
                        "clientInfo":{"name":"build","version":"1"}})
print("INIT:", "ok" if wait(i,15) else "TIMEOUT")
send("notifications/initialized", notif=True)
print("port 13469 listening after proxy start:", port_open(13469))

# wait for Studio to connect (it retries every ~5s)
print("\nWaiting for Studio to connect to the proxy...")
connected = False
for attempt in range(20):  # ~60s
    r = call("get_studio_state", {}, t=8)
    t = text_of(r) or ""
    if r and not r.get("result",{}).get("isError") and "Not connected" not in t and "Unable to find" not in t:
        connected = True
        print(f"  attempt {attempt+1}: CONNECTED")
        print("  studio_state:", t[:600])
        break
    print(f"  attempt {attempt+1}: {t[:80]}")
    time.sleep(3)

if not connected:
    print("\nRESULT: proxy is up but Studio never connected. (port13469 listening:", port_open(13469), ")")
    proc.terminate(); sys.exit(2)

# pin the active Studio instance
print("\n===== list_roblox_studios =====")
r = call("list_roblox_studios", {}, t=15)
listing = text_of(r) or ""
print(listing[:600])
import re
ids = re.findall(r'[0-9a-fA-F]{6,}|studio[_-]?\w+|"id"\s*:\s*"([^"]+)"', listing)
ids = [i for i in ids if i]
if ids:
    sid = ids[0]
    print("setting active studio:", sid)
    print(text_of(call("set_active_studio", {"studio_id": sid}, t=15)) or "")

# run the build, retrying through any place-loading window
print("\n===== execute_luau (building land) =====")
code = open(os.path.join(os.path.dirname(__file__),"build_land.lua"),"r",encoding="utf-8").read()
out = None
for attempt in range(8):
    r = call("execute_luau", {"code":code, "datamodel_type":"Edit"}, t=90)
    out = text_of(r) or "(no response)"
    retryable = ("disconnected" in out or "doesn't have a place" in out
                 or "Not connected" in out or "Unable to find" in out)
    print(f"  attempt {attempt+1}: {out[:120]}")
    if not retryable:
        break
    time.sleep(4)
print("\nFINAL execute_luau result:")
print(out)

print("\n===== verify what exists in the DataModel =====")
verify_lua = '''
local root = workspace:FindFirstChild("SimulatorLand")
if not root then return "MISSING SimulatorLand" end
local plots, signs, fences, dirt = 0,0,0,0
for _, plot in ipairs(root:GetChildren()) do
	if plot.Name:match("^Plot%d+$") then
		plots += 1
		if plot:FindFirstChild("Dirt") then dirt += 1 end
		if plot:FindFirstChild("Sign") then signs += 1 end
		for _, p in ipairs(plot:GetChildren()) do if p.Name == "Fence" then fences += 1 end end
	end
end
local island = root:FindFirstChild("GrassIsland")
local spawn = root:FindFirstChild("CenterSpawn")
return string.format(
	"island=%s size=%s | spawn=%s | plots=%d dirt=%d signs=%d fences=%d | totalDescendants=%d",
	tostring(island ~= nil), island and tostring(island.Size) or "-",
	tostring(spawn ~= nil), plots, dirt, signs, fences, #root:GetDescendants())
'''
r = call("execute_luau", {"code":verify_lua, "datamodel_type":"Edit"}, t=30)
print("VERIFY:", text_of(r))

print("\n===== console output =====")
r = call("get_console_output", {}, t=20)
print((text_of(r) or "(none)")[:2000])

proc.terminate()
print("\nDONE")

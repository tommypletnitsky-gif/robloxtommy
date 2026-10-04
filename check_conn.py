"""Exit 0 if Studio's MCP host is reachable (a place/instance is served), else 1."""
import json, sys, subprocess, threading, queue, time, glob, os

EXE = glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\StudioMCP.exe"))[0]
proc = subprocess.Popen([EXE], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                        stderr=subprocess.DEVNULL, text=True, encoding="utf-8", bufsize=1)
q = queue.Queue()
def reader():
    for line in proc.stdout:
        line = line.strip()
        if line:
            try: q.put(json.loads(line))
            except Exception: pass
threading.Thread(target=reader, daemon=True).start()
def send(o): proc.stdin.write(json.dumps(o)+"\n"); proc.stdin.flush()
def wait(i, t):
    end=time.time()+t
    while time.time()<end:
        try: m=q.get(timeout=0.2)
        except queue.Empty: continue
        if m.get("id")==i: return m
    return None

send({"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"chk","version":"1"}}})
if not wait(1,10):
    sys.exit(1)
send({"jsonrpc":"2.0","method":"notifications/initialized"})
send({"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_studio_state","arguments":{}}})
r = wait(2,10)
try: proc.terminate()
except Exception: pass
if not r: sys.exit(1)
txt = json.dumps(r)
if r.get("result",{}).get("isError") or "Not connected" in txt or "Unable to find" in txt:
    print("waiting"); sys.exit(1)
print("connected"); sys.exit(0)

"""Drive the Roblox Studio MCP proxy (StudioMCP.exe) over stdio.

Usage: python mcp_drive.py <requests.json>
  <requests.json> is a JSON array of {"method":..., "params":...} tool calls
  (the initialize handshake is done automatically).
Prints each response as it arrives.
"""
import json, sys, subprocess, threading, queue, time, glob, os

VER = glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\StudioMCP.exe"))
EXE = VER[0]

proc = subprocess.Popen([EXE], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE, text=True, encoding="utf-8", bufsize=1)

responses = queue.Queue()
def reader():
    for line in proc.stdout:
        line = line.strip()
        if not line:
            continue
        try:
            responses.put(json.loads(line))
        except Exception:
            responses.put({"_raw": line})
threading.Thread(target=reader, daemon=True).start()

def send(obj):
    proc.stdin.write(json.dumps(obj) + "\n")
    proc.stdin.flush()

def wait_for(want_id, timeout):
    end = time.time() + timeout
    while time.time() < end:
        try:
            msg = responses.get(timeout=0.2)
        except queue.Empty:
            continue
        if msg.get("id") == want_id:
            return msg
        # print stray notifications/logs
        if "id" not in msg:
            print("NOTE:", json.dumps(msg)[:300])
    return None

# 1. handshake
send({"jsonrpc":"2.0","id":1,"method":"initialize",
      "params":{"protocolVersion":"2024-11-05","capabilities":{},
                "clientInfo":{"name":"driver","version":"1.0"}}})
init = wait_for(1, 15)
print("INIT:", "ok" if init else "TIMEOUT")
if not init:
    sys.exit(1)
send({"jsonrpc":"2.0","method":"notifications/initialized"})

# 2. run requested tool calls
calls = json.load(open(sys.argv[1], "r", encoding="utf-8"))
next_id = 2
for c in calls:
    req = {"jsonrpc":"2.0","id":next_id,"method":c["method"]}
    if "params" in c:
        req["params"] = c["params"]
    label = c.get("params",{}).get("name", c["method"])
    print(f"\n===== CALL #{next_id}: {label} =====")
    send(req)
    timeout = c.get("timeout", 30)
    resp = wait_for(next_id, timeout)
    if resp is None:
        print("  -> TIMEOUT after", timeout, "s (no response from Studio)")
    else:
        out = json.dumps(resp.get("result", resp.get("error", resp)), indent=2)
        print(out[:4000])
    next_id += 1

try:
    proc.stdin.close()
    proc.terminate()
except Exception:
    pass

import sys
import time
import pypresence
import json

client_id = "798647747678568488"
pid = 9999

todo = str(sys.argv[1]) if len(sys.argv) > 1 else "shutdown"
state = str(sys.argv[2]) if len(sys.argv) > 2 else "state = (Idle)"
data = str(sys.argv[3]) if len(sys.argv) > 3 else "{}"
# start = int(sys.argv[4]) if len(sys.argv) > 4 else int(time.time())
# end = int(sys.argv[5]) if len(sys.argv) > 5 else int(time.time() + 60)
# large_image = str(sys.argv[6]) if len(sys.argv) > 6 else "mpv"
# large_text = str(sys.argv[7]) if len(sys.argv) > 7 else "large_text = mpv Media Player"
# small_image = str(sys.argv[8]) if len(sys.argv) > 8 else "player_stop"
# small_text = str(sys.argv[9]) if len(sys.argv) > 9 else "small_text = Idle"
# periodic_timer = int(sys.argv[10]) if len(sys.argv) > 10 else 15

data = json.loads(data)
print(data)

RPC = pypresence.Presence(client_id)
RPC.connect()
if todo == "shutdown":
	RPC.clear()
	RPC.close()
elif todo == "idle" or todo == "not-idle":
	RPC.update(state=state, details=details, start=start, large_image=large_image, large_text=large_text, small_image=small_image, small_text=small_text)

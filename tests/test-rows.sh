#!/bin/sh
# Attach a narrow client and a wide one to a private tmux server and check
# the row count. Does not touch the default server.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
sock=tmux-adaptive-status-test
tmux -L "$sock" kill-server >/dev/null 2>&1 || true

wrap=$(mktemp -d)
cleanup() {
	tmux -L "$sock" kill-server >/dev/null 2>&1 || true
	rm -rf "$wrap"
}
trap cleanup EXIT

cat > "$wrap/tmux" << EOF
#!/bin/sh
exec $(command -v tmux) -L "$sock" "\$@"
EOF
chmod +x "$wrap/tmux"

# The plugin and status-rows call plain tmux. The wrapper pins them to this
# socket. Unset TMUX so a shell already inside another server cannot leak.
export PATH="$wrap:$PATH"
unset TMUX
export STATUS_ROWS="$root/scripts/status-rows"

tmux -f /dev/null new-session -d -s s "sleep 90"
tmux set -g @adaptive-status-cols 60
tmux set -g @adaptive-status-segment "SEG"
"$root/adaptive-status.tmux"

python3 - "$sock" << 'PY'
import os, pty, struct, fcntl, termios, subprocess, time, sys
sock = sys.argv[1]
env = os.environ.copy()
env["TERM"] = "xterm-256color"

def tmux(*args):
    return subprocess.check_output(["tmux", "-L", sock, *args], text=True)

def attach(rows, cols):
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
    proc = subprocess.Popen(
        ["tmux", "-L", sock, "-f", "/dev/null", "attach", "-t", "s"],
        stdin=slave, stdout=slave, stderr=slave, env=env, start_new_session=True,
    )
    os.close(slave)
    return master, proc

def status():
    time.sleep(0.45)
    return tmux("show", "-v", "status").strip()

def expect(label, want):
    got = status()
    print(f"{label}: {got}")
    if got != want:
        raise SystemExit(f"{label}: want {want}, got {got}")

narrow_m, narrow_p = attach(24, 43)
expect("narrow attach", "2")
wide_m, wide_p = attach(40, 150)
expect("wide attach", "on")
os.write(narrow_m, b"x")
expect("key on narrow", "2")
os.write(wide_m, b"x")
expect("key on wide", "on")

# The script must honor the tty it is given, not whichever client is current.
tty = tmux("list-clients", "-F", "#{client_tty} #{client_width}").splitlines()
narrow_tty = next(line.split()[0] for line in tty if int(line.split()[1]) < 60)
subprocess.check_call(["tmux", "-L", sock, "set", "status", "on"])
script = os.environ["STATUS_ROWS"]
subprocess.check_call([script, narrow_tty], env={**env, "PATH": os.environ["PATH"]})
expect("script on narrow tty", "2")

right = tmux("show", "-gv", "status-right")
if "SEG" not in right or "@adaptive-status-cols" not in right:
    raise SystemExit(f"status-right missing segment: {right}")
line2 = tmux("show", "-gv", "status-format[1]")
if "SEG" not in line2:
    raise SystemExit(f"status-format[1] missing segment: {line2}")

narrow_p.terminate()
wide_p.terminate()
print("ok")
PY

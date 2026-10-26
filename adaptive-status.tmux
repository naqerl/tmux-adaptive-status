#!/usr/bin/env bash
# One status row on a wide client, two on a narrow one.
# TPM executes this file. From tmux.conf: run-shell '/path/to/adaptive-status.tmux'
set -euo pipefail

dir=$(cd "$(dirname "$0")" && pwd)
rows="$dir/scripts/status-rows"

if ! tmux show -gv @adaptive-status-cols >/dev/null 2>&1; then
	if tmux show -gv @status_cols >/dev/null 2>&1; then
		tmux set -g @adaptive-status-cols "$(tmux show -gv @status_cols)"
	else
		tmux set -g @adaptive-status-cols 60
	fi
fi

segment=$(tmux show -gv @adaptive-status-segment 2>/dev/null || true)
if [ -n "$segment" ]; then
	# Drawn per client, so a wide terminal keeps the segment on the right
	# even while the session is temporarily in two-row mode.
	tmux set -g status-right "#{?#{e|>=|:#{client_width},#{@adaptive-status-cols}},${segment},}"
	tmux set -g 'status-format[1]' "#{?#{e|<|:#{client_width},#{@adaptive-status-cols}},${segment},}"
fi

# #{hook_client} is the client that attached, resized, or became active.
# #{client_width} here would be whichever client is current.
hook="run-shell \"$rows #{hook_client}\""
tmux set-hook -g client-attached "$hook"
tmux set-hook -g client-active "$hook"
tmux set-hook -g client-resized "$hook"

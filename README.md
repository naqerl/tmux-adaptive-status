# tmux-adaptive-status

One tmux status row on a wide terminal, two on a narrow one.

The row count is a session option, so every client attached to the session shares it. It follows the client that just attached, resized, or became the window's latest. A segment you choose sits on the right of row 1 when that client is wide enough, and moves to row 2 when it is narrow.

`#{client_width}` inside a hook is the current client. That stays the desktop when the phone resizes or comes to the foreground, so the hook passes `#{hook_client}` and the script reads that client's width.

## Install

Clone the repo, then add this above any `run '~/.tmux/plugins/tpm/tpm'` line:

```tmux
set -g @adaptive-status-cols 60
set -g @adaptive-status-segment '#(~/bin/my-status)'
run-shell '~/src/tmux-adaptive-status/adaptive-status.tmux'
```

With [TPM](https://github.com/tmux-plugins/tpm), set the two options and then:

```tmux
set -g @plugin 'naqerl/tmux-adaptive-status'
```

TPM runs every executable `*.tmux` file in the plugin directory. Reload with `tmux source-file ~/.tmux.conf`.

`@adaptive-status-cols` is the minimum width, in columns, for a single row. It defaults to 60. `@status_cols` is still read if the new option is unset.

`@adaptive-status-segment` is a tmux format. On a wide client it is `status-right`. On a narrow client it is row 2 (`status-format[1]`). Leave it unset to keep your existing right-hand side and only switch the row count. A segment that itself contains a comma must escape it as `#,`, because the comma splits the width conditional.

The segment is read when the plugin runs. Change it and source the config again.

If the segment runs a command (`#(...)`), set `status-interval` to the refresh you want. The plugin does not change that interval.

## Behavior

- Opening or resizing the narrow client selects two rows. A key there does the same once that client becomes the window's latest.
- Opening or resizing the wide client selects one row.
- While the phone is the client that last changed the row count, the desktop also shows two rows. Its copy of row 2 is empty, because its own width still draws the segment on the right. The next resize or key on the desktop restores one row.

## Test

`tests/test-rows.sh` starts its own tmux server (`-L tmux-adaptive-status-test`) and does not attach to any other server.

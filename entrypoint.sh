#!/usr/bin/env bash
set -euo pipefail

SESSION="${TMUX_SESSION:-agents}"
CLAUDE_DIR="${CLAUDE_PROJECT_DIR:-/home/ayo/Projects}"
CODEX_DIR="${CODEX_PROJECT_DIR:-/home/ayo/Projects}"
TTYD_PORT="${TTYD_PORT:-7681}"

: "${TTYD_USER:?TTYD_USER must be set in .env}"
: "${TTYD_PASS:?TTYD_PASS must be set in .env}"

mkdir -p /home/ayo/.agent-state

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux new-session -d -s "$SESSION" -n main -c "$CLAUDE_DIR"
  tmux split-window -h -t "${SESSION}:main" -c "$CODEX_DIR"
  # Auto-start both CLIs on session creation (container start/restart).
  tmux send-keys -t "${SESSION}:main.0" 'claude' C-m
  tmux send-keys -t "${SESSION}:main.1" 'codex' C-m
  tmux select-pane -t "${SESSION}:main.0"
fi

node /home/ayo/status-server/server.js &

# Extra ad hoc agents: from any pane, `tmux new-window -n <task> -c /home/ayo/Projects/<proj>`.
# They show up in the same ttyd view and are picked up automatically by the status panel.

exec ttyd -p "$TTYD_PORT" -c "${TTYD_USER}:${TTYD_PASS}" -W \
  tmux attach-session -t "$SESSION"

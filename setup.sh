#!/usr/bin/env bash
# Installs the agent container setup into ~/.local/agents:
#   - copies Dockerfile and docker-compose.yml (overwritten, so re-running updates them)
#   - creates home/, the folder mounted as the container's $HOME (configs and OAuth logins)
# Run it from anywhere; it copies the files that sit next to this script.
# Safe to run repeatedly.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.local/agents"
AGENT_HOME="$INSTALL_DIR/home"

for f in Dockerfile Dockerfile.project docker-compose.yml; do
  if [ ! -f "$SRC_DIR/$f" ]; then
    echo "ERROR: $SRC_DIR/$f not found (it must sit next to setup.sh)." >&2
    exit 1
  fi
done

if [ -e "$AGENT_HOME" ] && [ ! -d "$AGENT_HOME" ]; then
  echo "ERROR: $AGENT_HOME exists but is not a directory." >&2
  exit 1
fi

if [ -d "$AGENT_HOME" ]; then
  owner=$(stat -c %u "$AGENT_HOME")
  if [ "$owner" != "$(id -u)" ]; then
    echo "ERROR: $AGENT_HOME is owned by UID $owner, not you (probably created by Docker)." >&2
    echo "       Fix with: sudo chown -R $(id -u):$(id -g) '$AGENT_HOME'" >&2
    exit 1
  fi
  echo "ok      $AGENT_HOME"
else
  mkdir -p "$AGENT_HOME"
  echo "created $AGENT_HOME"
fi

# Holds OAuth tokens: keep it private to you
chmod 700 "$AGENT_HOME"

# Always copy, so edits to the files reach the installed copy
if [ "$SRC_DIR" != "$INSTALL_DIR" ]; then
  install -m 644 "$SRC_DIR/Dockerfile" "$SRC_DIR/Dockerfile.project" "$SRC_DIR/docker-compose.yml" "$INSTALL_DIR/"
  echo "copied  Dockerfile, Dockerfile.project, docker-compose.yml -> $INSTALL_DIR"
fi

# Keep home/ (tokens, caches) out of the Docker build context
printf 'home\n' > "$INSTALL_DIR/.dockerignore"
echo "wrote   $INSTALL_DIR/.dockerignore"
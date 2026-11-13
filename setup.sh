#!/usr/bin/env bash
# Installs the agent container setup into ~/.local/agents:
#   - copies Dockerfile and docker-compose.yml (overwritten, so re-running updates them)
#   - creates home/, the folder mounted as the container's $HOME (configs and OAuth logins)
#   - writes the agent() function into ~/.bashrc (replacing any earlier copy)
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

# Install the agent() function: delete any earlier copy, then append this one.
# The quoted 'EOF' keeps the variables from being expanded while writing.
touch "$HOME/.bashrc"
sed -i '/# >>> agent function >>>/,/# <<< agent function <<</d' "$HOME/.bashrc"
cat >> "$HOME/.bashrc" <<'EOF'
# >>> agent function >>>
agent() {
  local dir="$HOME/.local/agents" today file= img=
  # agent -f <Dockerfile> ...: run on top of the project's own image
  if [ "$1" = -f ]; then file=$2; shift 2; fi
  [ -d "$dir/home" ] || { echo "agent: not installed, run setup.sh first" >&2; return 1; }
  # The stamp file decides when to update. A new day resets it; a forced update
  # (see README) writes today's date plus a suffix, which then lasts for the day.
  today=$(date +%F)
  case "$(cat "$dir/cache-date" 2>/dev/null)" in
    "$today"*) ;;
    *) echo "$today" > "$dir/cache-date" ;;
  esac
  local -x HOST_UID HOST_GID   # exported to docker compose, gone after the function returns
  HOST_UID=$(id -u) HOST_GID=$(id -g)
  if ! docker compose -f "$dir/docker-compose.yml" build \
         --build-arg CACHE_DATE="$(cat "$dir/cache-date")" agent; then
    docker image inspect code-agents:local >/dev/null 2>&1 || return 1
    echo "agent: update failed, starting the existing image" >&2
  fi
  if [ -n "$file" ]; then
    img="agent-$(printf %s "$PWD" | sha1sum | cut -c1-12)"
    docker build -t "$img-base" -f "$file" . &&
    docker build -t "$img" --build-arg BASE="$img-base" -f "$dir/Dockerfile.project" "$dir" || return 1
  fi
  AGENT_IMAGE="$img" docker compose -f "$dir/docker-compose.yml" run --rm -v "$PWD:$PWD" -w "$PWD" agent "$@"
}
# <<< agent function <<<
EOF
echo "wrote   agent() function to ~/.bashrc (run: source ~/.bashrc)"

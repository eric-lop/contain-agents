# Containerized AI coding agents

Run **OpenCode**, **Claude Code** and **Codex** (plus Blender and FreeCAD for headless CAD work) inside a Docker container. The agents can see only the project folder you run them from and their own home folder (`~/.local/agents/home`).

## Install

1. Put `Dockerfile`, `Dockerfile.project`, `docker-compose.yml` and `setup.sh` together in one folder, then run the installer from it:
   ```bash
   bash setup.sh
   ```
   This copies `Dockerfile` and `docker-compose.yml` to `~/.local/agents/` and creates `~/.local/agents/home/`, the folder mounted as the container's home. After editing either file, run `setup.sh` again to update the installed copy.

2. Add the `agent` command to `~/.bashrc`:
   ```bash
   sed -i '/# >>> agent function >>>/,/# <<< agent function <<</d' ~/.bashrc
   cat >> ~/.bashrc <<'EOF'
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
   source ~/.bashrc
   ```
   The `sed` line removes any earlier version first, so running this again replaces the function instead of adding a second copy. The quoted `'EOF'` keeps the variables from being expanded while writing.

3. Run `agent` once from a project folder. The first build takes a while because of Blender and FreeCAD.

## Usage

From inside any project folder:

```bash
agent claude      # Claude Code
agent codex       # Codex
agent opencode    # OpenCode (v2 may install it as `opencode2`; check with `agent bash -c 'ls /usr/local/bin'`)
agent bash        # a shell in the container, to look around
```

`agent` mounts whatever folder you run it from, with no checks. Never run it from `~`, a folder above it, or a folder holding credentials (such as `~/.ssh` or `~/.local`, where the agents' tokens live). The current folder is mounted at the same path as on your host, which keeps each project's sessions and history separate.

### Projects with their own Dockerfile

For a project (such as a C++ one) whose Dockerfile installs its toolchain and dependencies, pass it with `-f` so the agents run inside that environment:

```bash
agent -f Dockerfile claude
agent -f docker/dev.Dockerfile bash
```

`agent` builds the project's Dockerfile with the project folder as context, then copies the agents on top using `Dockerfile.project`. The mounts and restrictions are the same as usual.

- The project image must be glibc-based (Debian, Ubuntu, Fedora...). It should include `git` and `ca-certificates` if the agents need them.
- Blender and FreeCAD aren't included in this mode.
- Each project leaves images named `agent-<hash>` and `agent-<hash>-base`. List them with `docker image ls 'agent-*'` and remove old ones with `docker image rm`.

### Logging in

Use OAuth (`/login` in Claude Code, `codex login`, `/connect` in OpenCode). The tokens are saved in `~/.local/agents/home`, so you only log in once.

## Updates

The image rebuilds itself on the **first `agent` call of each day**. The function keeps the build date in `~/.local/agents/cache-date` and passes it as the `CACHE_DATE` build argument. When the date changes, the harness layers are reinstalled with the latest releases. Later calls that day use the cache and start in a couple of seconds. The large `apt-get` layer stays cached.

If the daily rebuild fails (you're offline, or a vendor's installer is down), `agent` prints a warning and starts the image you already have.

- Force an update now. The next `agent` call rebuilds, and the forced version stays in use for the rest of the day:
  ```bash
  echo "$(date +%F)-$(date +%s)" > ~/.local/agents/cache-date
  ```
- Update hourly instead: change `date +%F` to `date +%F-%H` in the function, and in the force command above.
- Clean up old image layers now and then: `docker image prune`.

Claude Code's built-in auto-updater is turned off (`DISABLE_AUTOUPDATER=1`), because it would otherwise download copies into the persistent home folder. The binaries in `/opt` are read-only for your user, and the container is discarded after each run. The daily rebuild is what keeps you current.

## Security notes

- **Assume anything in the container can reach the model provider.** Keep secrets (`.env` files, keys) out of project folders you run agents in.
- **OAuth tokens are files in `~/.local/agents/home`.** All three agents can read each other's tokens. The realistic risk is prompt injection, such as a malicious file or web page tricking an agent into leaking them. You can revoke sessions from each provider's account settings.
- **The agents can write anything in `~/.local/agents/home`,** including startup files like `.bashrc`. Look in it now and then, or wipe it and log in again.
- **The installers are not pinned.** Every daily rebuild runs each vendor's `curl | sh` installer, so you trust those download servers each day.
- **Network access is unrestricted by default.** To block data from going anywhere except the providers, put the container on an `internal: true` network behind an allowlisting proxy (such as Squid) that only permits the providers' API domains.

## Uninstall

```bash
docker compose -f ~/.local/agents/docker-compose.yml down --rmi all
rm -rf ~/.local/agents
sed -i '/# >>> agent function >>>/,/# <<< agent function <<</d' ~/.bashrc
```

Then open a new terminal, or run `unset -f agent`.
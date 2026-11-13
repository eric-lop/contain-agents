# Containerized AI coding agents

Run **OpenCode**, **Claude Code** and **Codex** (plus Blender and FreeCAD for headless CAD work) inside a Docker container. The agents can see only the project folder you run them from and their own home folder (`~/.local/agents/home`).

## Install

1. Put `Dockerfile`, `docker-compose.yml` and `setup.sh` together in one folder, then run the installer from it:
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
     local dir="$HOME/.local/agents"
     case "$HOME/" in
       "${PWD%/}/"*) echo "agent: refusing to mount $PWD (contains your home)" >&2; return 1 ;;
     esac
     case "$PWD/" in
       "$HOME"/.ssh/*|"$HOME"/.gnupg/*|"$HOME"/.aws/*|"$HOME"/.config/*|"$HOME"/.local/*)
         echo "agent: refusing to mount $PWD" >&2; return 1 ;;
     esac
     [ -d "$dir/home" ] || { echo "agent: not installed, run setup.sh first" >&2; return 1; }
     docker compose -f "$dir/docker-compose.yml" build --build-arg CACHE_DATE="$(date +%F)" agent || return 1
     HOST_UID=$(id -u) HOST_GID=$(id -g) \
     docker compose -f "$dir/docker-compose.yml" run --rm -v "$PWD:$PWD" -w "$PWD" agent "$@"
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

`agent` refuses to run from `~` or any folder above it (such as `/home` or `/`), and from inside `~/.ssh`, `~/.gnupg`, `~/.aws`, `~/.config` or `~/.local`. So it never mounts your whole home, your credentials or the agents' own tokens as a project. The current folder is mounted at the same path as on your host, which keeps each project's sessions and history separate.

### Logging in

Use OAuth (`/login` in Claude Code, `codex login`, `/connect` in OpenCode). The tokens are saved in `~/.local/agents/home`, so you only log in once.

## Updates

The image rebuilds itself on the **first `agent` call of each day**. The `CACHE_DATE` build argument changes daily, which reinstalls the harness layers with the latest releases. Later calls that day use the cache and start in a couple of seconds. The large `apt-get` layer stays cached.

- Force an update now:
  ```bash
  docker compose -f ~/.local/agents/docker-compose.yml build --build-arg CACHE_DATE=$(date +%s)
  ```
- Update hourly instead: change `date +%F` to `date +%F-%H` in the function.
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
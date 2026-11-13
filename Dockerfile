FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates git ripgrep \
        blender freecad \
    && rm -rf /var/lib/apt/lists/*

# Changes daily -> everything below is reinstalled with the latest versions
ARG CACHE_DATE=unset
RUN echo "harness build: $CACHE_DATE"

RUN curl -fsSL https://opencode.ai/v2/install | HOME=/opt/opencode bash
RUN curl -fsSL https://claude.ai/install.sh    | HOME=/opt/claude bash
RUN curl -fsSL https://chatgpt.com/codex/install.sh | HOME=/opt/codex sh

RUN for d in /opt/opencode/.opencode/bin /opt/claude/.local/bin /opt/codex/.local/bin; do \
        [ -d "$d" ] && for f in "$d"/*; do \
            ln -sf "$(readlink -f "$f")" "/usr/local/bin/$(basename "$f")"; \
        done; \
    done; \
    chmod -R a+rX /opt; \
    ls -l /usr/local/bin

# Match the host user (compose runs the container as HOST_UID:HOST_GID), so the
# user has a passwd entry. -o tolerates a UID that already exists in the image.
ARG HOST_UID=1000
ARG HOST_GID=1000
RUN getent group "$HOST_GID" >/dev/null || groupadd --gid "$HOST_GID" code-assistant; \
    useradd --create-home -o --uid "$HOST_UID" --gid "$HOST_GID" --shell /bin/bash code-assistant
USER code-assistant
ENV HOME=/home/code-assistant

RUN claude --version && codex --version \
    && { ls /usr/local/bin | grep -q '^opencode' || { echo "opencode not installed" >&2; exit 1; }; }
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

RUN useradd --create-home --uid 1000 --shell /bin/bash code-assistant
USER code-assistant
ENV HOME=/home/code-assistant

RUN claude --version && codex --version \
    && { ls /usr/local/bin | grep -q '^opencode' || { echo "opencode not installed" >&2; exit 1; }; }
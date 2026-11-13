# AGENTS.md

This project runs AI coding agents in a Docker container: `Dockerfile`, `Dockerfile.project`, `docker-compose.yml`, `setup.sh`, and the `agent()` shell function that `setup.sh` writes into `~/.bashrc`.

## Guiding principle: keep it simple

The setup must stay easy to understand and debug when something goes wrong.

- Write the simplest version that works. Fewer lines beat more cases handled.
- Don't add safety guards, input validation or fallbacks for rare cases unless asked. The user knows the limits and will remember them.
- When you skip an edge case, list it briefly as "can be added if needed" instead of implementing it.
- Prefer plain, readable shell and Dockerfile code over clever tricks. A short comment explaining *why* is welcome.
- Keep `README.md` in sync with any change to the files or to the `agent()` function.

# Agent47

Docker Compose setup for running Claude Code and MCP servers in containers.

> **Note:**

- Docker rootless mode is not supported. The containers require standard Docker with proper daemon access.
- Login to Claude Code before you start docker compose
- Create `.env` and update with your actual value

## Quick Start

```bash
# Set your UID/GID (defaults to 1000)
export USER_ID=$(id -u)
export GROUP_ID=$(id -g)

# Build and run
docker compose up -d --build
```

## Services

### Claude Code

Containerized Claude Code CLI with Node.js 24, Rust, and Docker CLI. Mounts `~/development` as the working directory.

```bash
# Shell into the container
docker compose exec claude-code bash
```

To mount a different directory, edit the volume in `docker-compose.yml`:

```yaml
- ${HOME}/development:/home/agent/development:rw
```

### Playwright MCP

Browser automation MCP server on port 8931. Connect Claude Code to it with:

```json
{
  "mcpServers": {
    "playwright": {
      "url": "http://mcp-playwright:8931/mcp"
    }
  }
}
```

## Dev Environment (9 containers)

Run 9 SSH-accessible dev containers sharing a Verdaccio npm cache.

### Setup

```bash
# 1. Create shared network (once)
docker network create orochi-network

# 2. Start Verdaccio npm cache
docker compose -f docker-compose-verdaccio.yaml up -d

# 3. Configure environment
cp .env.example .env
# Edit .env: set USER_ID, GROUP_ID, HOME_FOLDER, DEV_N_MOUNT paths

# 4. Start dev containers
docker compose -f docker-compose-dev.yaml up -d --build
```

### SSH Access

Each container exposes SSH on a predictable port (2201–2209):

```bash
ssh agent@localhost -p 2201   # dev-1
ssh agent@localhost -p 2202   # dev-2
# ...
ssh agent@localhost -p 2209   # dev-9
```

### npm via Verdaccio

Add to `~/.npmrc` (or project `.npmrc`) to route npm through the local cache:

```
registry=http://verdaccio:4873
```

Web UI available at `http://localhost:4873`. First install fetches from npmjs.org; subsequent installs are served from the local cache.

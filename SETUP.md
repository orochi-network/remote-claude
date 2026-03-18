# Server Setup Guide

Start-to-finish setup of the dev container environment on a blank Ubuntu server.

## Requirements

- Ubuntu 22.04+ (Noble recommended)
- 8 GB RAM minimum, 16 GB recommended for 9 containers
- 50 GB disk space (for Docker images + Verdaccio cache)
- Root or sudo access

---

## Step 1 — Install Docker

```bash
# Install Docker Engine (official script)
curl -fsSL https://get.docker.com | sh

# Add your user to the docker group (no sudo needed after re-login)
sudo usermod -aG docker $USER
newgrp docker

# Verify
docker version
```

---

## Step 2 — Clone the Repository

```bash
git clone <repo-url> ~/agent47
cd ~/agent47
```

---

## Step 3 — Configure Environment

```bash
cp .env.example .env
```

Edit `.env` to match your server:

```env
USER_ID=1000           # run: id -u
GROUP_ID=1000          # run: id -g
HOME_FOLDER=/home/youruser

# Per-container workspace paths (created automatically if missing)
DEV_1_MOUNT=/home/youruser/workspaces/dev-1
DEV_2_MOUNT=/home/youruser/workspaces/dev-2
DEV_3_MOUNT=/home/youruser/workspaces/dev-3
DEV_4_MOUNT=/home/youruser/workspaces/dev-4
DEV_5_MOUNT=/home/youruser/workspaces/dev-5
DEV_6_MOUNT=/home/youruser/workspaces/dev-6
DEV_7_MOUNT=/home/youruser/workspaces/dev-7
DEV_8_MOUNT=/home/youruser/workspaces/dev-8
DEV_9_MOUNT=/home/youruser/workspaces/dev-9
```

Get your actual IDs:

```bash
echo "USER_ID=$(id -u)"
echo "GROUP_ID=$(id -g)"
echo "HOME_FOLDER=$HOME"
```

---

## Step 4 — Add Developer SSH Keys

Each container has its own dedicated key file: `ssh/dev-N.pub`. Paste the developer's public key into the matching file:

```bash
# Assign a key to a container — one public key per file
cat ~/.ssh/id_ed25519.pub > ssh/dev-1.pub
cat /path/to/dev2_key.pub > ssh/dev-2.pub
# ... repeat for dev-3 through dev-9
```

Or generate a fresh keypair per container:

```bash
for i in $(seq 1 9); do
  ssh-keygen -t ed25519 -f ~/.ssh/id_dev$i -N "" -C "dev-$i"
  cat ~/.ssh/id_dev$i.pub > ssh/dev-$i.pub
done
```

Changes take effect after `docker compose restart dev-N` (only that container needs restart).

---

## Step 4b — Prepare Host Config Files

```bash
# .npmrc — create empty if you don't have one
touch ~/.npmrc
```

To configure npm to use Verdaccio (once it's running), add to `~/.npmrc`:

```
registry=http://verdaccio:4873
```

---

## Step 5 — Create Docker Network

```bash
docker network create orochi-network
```

---

## Step 6 — Start Verdaccio (npm cache)

```bash
docker compose -f docker-compose-verdaccio.yaml up -d
```

Verify it's running:

```bash
curl -s http://localhost:4873/  # should return Verdaccio HTML
```

---

## Step 7 — Build the Dev Image

Build once — all 9 containers share the same image:

```bash
docker build \
  --build-arg ARG_USER_ID=$(id -u) \
  --build-arg ARG_GROUP_ID=$(id -g) \
  -t agent47-dev \
  claude-code/
```

This takes ~5 min on first run (downloads base image, installs tools). Rebuild only when the Dockerfile changes.

## Step 7b — Start Dev Containers

```bash
docker compose -f docker-compose-dev.yaml up -d

# Check all 9 containers are up
docker compose -f docker-compose-dev.yaml ps
```

All 9 containers should show status `Up`.

---

## Step 8 — Verify SSH Access

Keys are loaded from `ssh/dev-N.pub` at container start — no manual injection needed.

```bash
# Test connection (use the matching private key)
ssh -i ~/.ssh/id_dev1 agent@<server-ip> -p 2201

# Rotate a key: update the file, restart only that container
cat new_key.pub > ssh/dev-3.pub
docker compose -f docker-compose-dev.yaml restart dev-3
```

---

## Step 9 — Connect via SSH

```bash
ssh -i ~/.ssh/id_dev1 agent@<server-ip> -p 2201   # dev-1
ssh -i ~/.ssh/id_dev2 agent@<server-ip> -p 2202   # dev-2
# ...
```

Add to `~/.ssh/config` on your local machine for convenience:

```
Host dev-1
  HostName <server-ip>
  Port 2201
  User agent
  IdentityFile ~/.ssh/id_dev1

Host dev-2
  HostName <server-ip>
  Port 2202
  User agent
  IdentityFile ~/.ssh/id_dev2
```

Then just: `ssh dev-1`

---

## Management

```bash
# Stop all containers
docker compose -f docker-compose-dev.yaml down

# Restart a single container
docker compose -f docker-compose-dev.yaml restart dev-3

# View logs
docker compose -f docker-compose-dev.yaml logs -f dev-1

# Rebuild image after Dockerfile changes, then recreate containers
docker build --build-arg ARG_USER_ID=$(id -u) --build-arg ARG_GROUP_ID=$(id -g) -t agent47-dev claude-code/
docker compose -f docker-compose-dev.yaml up -d --force-recreate

# Verdaccio web UI
open http://<server-ip>:4873
```

## Ports Reference

| Service     | Port  | Protocol |
|-------------|-------|----------|
| Verdaccio   | 4873  | HTTP     |
| dev-1       | 2201  | SSH      |
| dev-2       | 2202  | SSH      |
| dev-3       | 2203  | SSH      |
| dev-4       | 2204  | SSH      |
| dev-5       | 2205  | SSH      |
| dev-6       | 2206  | SSH      |
| dev-7       | 2207  | SSH      |
| dev-8       | 2208  | SSH      |
| dev-9       | 2209  | SSH      |
| mcp-playwright | 8931 | HTTP  |

#!/bin/bash
# Generate SSH host keys once (idempotent — skipped if keys already exist)
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    sudo ssh-keygen -A
fi

# Ensure .ssh dir exists with correct permissions (sshd requires 700)
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Install authorized keys from mounted staging file with correct permissions
# (bind-mounted :ro files can't be chmod'd directly, so we copy them)
if [ -f ~/.ssh/authorized_keys.pub ]; then
    cp ~/.ssh/authorized_keys.pub ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
fi

# Ensure agent user owns the development directory tree (bind-mount may be owned by a different UID on host)
sudo chown -R "$(id -u):$(id -g)" /home/agent/development

# Grant agent user access to Docker socket without sudo
# The socket GID varies per host, so we detect it at runtime
if [ -S /var/run/docker.sock ]; then
    DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
    if ! getent group docker > /dev/null 2>&1; then
        sudo groupadd -g "$DOCKER_GID" docker
    fi
    sudo usermod -aG docker agent
fi

# Start SSH daemon in background
sudo service ssh restart

# Hand off to CMD
exec "$@"

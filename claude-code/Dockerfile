FROM orochinetwork/ubuntu:node-rust-dev

ENV DEBIAN_FRONTEND=noninteractive

# Docker CLI repo (Ubuntu Noble) + install
RUN set -eux && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
      https://download.docker.com/linux/ubuntu noble stable" \
      > /etc/apt/sources.list.d/docker.list && \
    sudo apt-get update && \
    sudo apt-get install -y --no-install-recommends docker-ce-cli && \
    sudo apt-get clean

# Disable password auth — pubkey only
RUN echo "PasswordAuthentication no" | sudo tee -a /etc/ssh/sshd_config && \
    echo "PubkeyAuthentication yes" | sudo tee -a /etc/ssh/sshd_config

# Ensure workdir exists with correct ownership (WORKDIR as non-root can have permission issues)
RUN mkdir -p /home/agent/development
WORKDIR /home/agent/development

# Install Claude CLI
RUN curl -fsSL https://claude.ai/install.sh | bash

# Entrypoint: generate SSH host keys (once) and start sshd before handing off to CMD
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["zsh"]

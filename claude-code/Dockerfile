FROM orochinetwork/ubuntu:node-rust

ARG ARG_USER_ID=1009
ARG ARG_GROUP_ID=1009
ENV DEBIAN_FRONTEND=noninteractive

# Docker CLI repo (Ubuntu Noble)
RUN set -eux && \
    apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl gnupg && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
      https://download.docker.com/linux/ubuntu noble stable" \
      > /etc/apt/sources.list.d/docker.list
# Runtime tools (build tools already in baseimage via buildpack-deps:noble)
RUN apt-get update && apt-get install -y --no-install-recommends \
    netbase ripgrep gh sq wget openssh-client git \
    docker-ce-cli make unzip xz-utils patch imagemagick \
    sudo zsh openssh-server fonts-firacode language-pack-en \
    vim htop lsof net-tools netcat-openbsd telnet \
    screen tmux 

# Create agent user with host UID/GID, configure sudo and zsh as default shell
# Disable password auth — pubkey only
RUN set -eux && \
    groupadd -g ${ARG_GROUP_ID} agent && \
    useradd -d /home/agent -m -u ${ARG_USER_ID} -g ${ARG_GROUP_ID} -s /usr/bin/zsh agent && \
    echo 'agent ALL=(ALL:ALL) NOPASSWD: ALL' >> /etc/sudoers && \
    echo "PasswordAuthentication no" >> /etc/ssh/sshd_config && \
    echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config

USER agent
WORKDIR /home/agent/development
ENV HOME=/home/agent
SHELL ["/bin/bash", "-lc"]

# Pre-create .ssh dir with correct ownership so Docker bind mounts don't create it as root
RUN mkdir -p /home/agent/.ssh && chmod 700 /home/agent/.ssh

# Install Claude CLI
RUN curl -fsSL https://claude.ai/install.sh | bash

# Install oh-my-zsh (unattended — no interactive prompt)
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install zsh plugins
RUN git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions \
      /home/agent/.oh-my-zsh/custom/plugins/zsh-autosuggestions && \
    git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting \
      /home/agent/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

# Configure .zshrc: agnoster theme, plugins, TERM, PATH
RUN sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/' /home/agent/.zshrc && \
    sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' /home/agent/.zshrc && \
    echo 'export TERM=xterm-256color' >> /home/agent/.zshrc && \
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/agent/.zshrc

# Add Claude CLI local bin to PATH for bash sessions (legacy/non-interactive)
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/agent/.bashrc

# Configure npm global prefix to user-writable dir (avoids EACCES on npm install -g)
RUN mkdir -p /home/agent/.npm-global && \
    npm config set prefix '/home/agent/.npm-global'
RUN echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> /home/agent/.zshrc && \
    echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> /home/agent/.bashrc

# Expose corepack and yarn/pnpm shims system-wide
# Baseimage installs node at /usr/local/node/bin but only symlinks node/npm/npx to /usr/local/bin
# corepack enable puts shims into the specified dir so they're on PATH for all users
RUN sudo ln -s /usr/local/node/bin/corepack /usr/local/bin/corepack && \
    sudo /usr/local/node/bin/corepack enable --install-directory /usr/local/bin

# Entrypoint: generate SSH host keys (once) and start sshd before handing off to CMD
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["zsh"]

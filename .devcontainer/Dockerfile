FROM node:22

ARG DEBIAN_FRONTEND=noninteractive

# --- ROOT OPERATIONS ---

## System packages (Node.js already provided by base image)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc g++ make cmake \
    git curl wget ca-certificates gnupg openssh-client \
    python3 python3-pip python3-venv \
    ripgrep fd-find jq unzip \
    sudo locales \
  && rm -rf /var/lib/apt/lists/*

## Locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

## Starship prompt
RUN curl -sS https://starship.rs/install.sh | sh -s -- -y

## Prepare node user home and grant sudo
RUN mkdir -p /home/node/.claude /home/node/.config /home/node/.local/bin /home/node/.ssh /home/node/project \
  && echo "node ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/node

## Copy config files into image
COPY claude.json /home/node/.claude.json
COPY settings.json /home/node/.claude/settings.json
COPY known_hosts /home/node/.ssh/known_hosts

## Permissions
RUN chmod 700 /home/node/.ssh \
  && chmod 644 /home/node/.ssh/known_hosts \
  && chown -R node:node /home/node

# --- USER OPERATIONS ---
USER node

## Claude Code (native installer)
ENV PATH="/home/node/.local/bin:${PATH}"
RUN curl -fsSL https://claude.ai/install.sh | bash

## Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/home/node/.cargo/bin:${PATH}"

## Starship config
RUN starship preset bracketed-segments -o ~/.config/starship.toml \
  && echo 'eval "$(starship init bash)"' >> ~/.bashrc

## Git identity
RUN git config --global user.name "Matus Cvengros" \
  && git config --global user.email "matus.cvengros@gmail.com"

WORKDIR /home/node/project

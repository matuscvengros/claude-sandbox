FROM node:22

ARG DEBIAN_FRONTEND=noninteractive

# --- ROOT OPERATIONS ---
## System packages
RUN apt-get update
RUN apt-get install -y --no-install-recommends \
    # Build tools
    build-essential gcc g++ make cmake \
    # Version control & networking
    git curl wget ca-certificates gnupg openssh-client \
    # Python
    python3 python3-pip python3-venv \
    # CLI utilities
    ripgrep fd-find jq unzip \
    # System
    sudo locales

# Cleanup apt cache to reduce image size
RUN rm -rf /var/lib/apt/lists/*

## Locale
RUN sed -i '/en_US.UTF-8/s/^# //' /etc/locale.gen
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

## Shell: Starship prompt
RUN curl -sS https://starship.rs/install.sh | sh -s -- -y

## User: remove default node user, create claude user
RUN userdel -r node
RUN useradd -m -s /bin/bash -u 1000 claude
RUN mkdir -p /home/claude/.config /home/claude/.local/bin /home/claude/.ssh /home/claude/project
RUN echo "claude ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/claude

## SSH: known hosts
COPY known_hosts /home/claude/.ssh/known_hosts
RUN chmod 700 /home/claude/.ssh
RUN chmod 644 /home/claude/.ssh/known_hosts

## Claude Code: config files
RUN mkdir -p /home/claude/.claude
COPY .claude.json /home/claude/.claude.json
COPY settings.json /home/claude/.claude/settings.json

## Entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

## Finalize root: fix ownership
RUN chown -R claude:claude /home/claude

# --- USER OPERATIONS ---
USER claude

## Languages: Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/home/claude/.cargo/bin:${PATH}"

## Shell: Starship config
RUN starship preset bracketed-segments -o ~/.config/starship.toml
RUN echo 'eval "$(starship init bash)"' >> ~/.bashrc

## Git identity (configured at runtime via env vars)

## Claude Code: install
ENV PATH="/home/claude/.local/bin:${PATH}"
RUN curl -fsSL https://claude.ai/install.sh | bash

## Claude Code: plugins
RUN claude plugin marketplace add anthropics/claude-plugins-official
RUN claude plugin install superpowers@claude-plugins-official \
 && claude plugin install firecrawl@claude-plugins-official \
 && claude plugin install frontend-design@claude-plugins-official \
 && claude plugin install pyright-lsp@claude-plugins-official \
 && claude plugin install typescript-lsp@claude-plugins-official

WORKDIR /home/claude/project
ENTRYPOINT ["/entrypoint.sh"]

FROM ubuntu:24.04 AS base

ARG DEBIAN_FRONTEND=noninteractive

# All root operations grouped together for layer efficiency
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc g++ make cmake \
    git curl wget ca-certificates gnupg \
    python3 python3-pip python3-venv \
    ripgrep fd-find jq unzip \
    sudo locales \
  && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Node.js LTS (22.x)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
  && apt-get install -y nodejs \
  && rm -rf /var/lib/apt/lists/*

# Starship prompt (root install)
RUN curl -sS https://starship.rs/install.sh | sh -s -- -y

# Claude Code (global install)
RUN npm install -g @anthropic-ai/claude-code

# Create non-root user
RUN useradd -m -s /bin/bash -u 1000 claude \
  && mkdir -p /home/claude/.claude /home/claude/.config /home/claude/project \
  && chown -R claude:claude /home/claude

# Entrypoint (copy while still root)
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Switch to claude for all remaining user-space setup
USER claude

# Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/home/claude/.cargo/bin:${PATH}"

# Starship config
RUN starship preset gruvbox-rainbow -o /home/claude/.config/starship.toml \
  && echo 'eval "$(starship init bash)"' >> /home/claude/.bashrc

# -----------------------------------------------------------
# Default variant: autonomous with full tooling and plugins
# -----------------------------------------------------------
FROM base AS default

USER root
COPY settings/settings-default.json /home/claude/.claude/settings.json
COPY plugins/ /home/claude/.claude/plugins/
COPY setup-plugins.sh /tmp/setup-plugins.sh
RUN chmod +x /tmp/setup-plugins.sh \
  && chown -R claude:claude /home/claude/.claude

USER claude
WORKDIR /home/claude/project
ENTRYPOINT ["/entrypoint.sh"]

# -----------------------------------------------------------
# Safe variant: project-only access, normal permissions
# -----------------------------------------------------------
FROM base AS safe

USER root
COPY settings/settings-safe.json /home/claude/.claude/settings.json
RUN chown -R claude:claude /home/claude/.claude

USER claude
WORKDIR /home/claude/project
ENTRYPOINT ["/entrypoint.sh"]

FROM node:22 AS base

ARG DEBIAN_FRONTEND=noninteractive

# --- ROOT OPERATIONS ---
## System packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build tools
    build-essential gcc g++ make cmake \
    # Version control & networking
    git gh curl wget ca-certificates gnupg openssh-client \
    # Python
    python3 python3-pip python3-venv \
    # CLI utilities
    ripgrep fd-find jq unzip \
    # System
    sudo locales socat \
    && rm -rf /var/lib/apt/lists/*

## Locale
RUN sed -i '/en_US.UTF-8/s/^# //' /etc/locale.gen \
 && locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

## User: remove default node user, create claude user
RUN userdel -r node \
    && useradd -m -s /bin/bash -u 1000 claude \
    && mkdir -p /home/claude/.config /home/claude/.local/bin /home/claude/.ssh /home/claude/.claude /home/claude/project \
    && chmod 700 /home/claude/.ssh \
    && echo "claude ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/claude

## SSH: known hosts
COPY --chmod=644 ssh/known_hosts /home/claude/.ssh/known_hosts

## Claude Code: config
COPY claude/.claude.json /home/claude/.claude.json
COPY claude/settings.json /home/claude/.claude/settings.json

## Entrypoint
COPY --chmod=755 entrypoint.sh /entrypoint.sh

## Finalize root: fix ownership
RUN chown -R claude:claude /home/claude

# --- USER OPERATIONS ---
USER claude

## Shared credential setup script
COPY --chmod=755 --chown=claude:claude scripts/setup-credentials.sh /tmp/setup-credentials.sh

## Shell: Starship prompt
RUN curl -sS https://starship.rs/install.sh | sh -s -- -y \
    && starship preset bracketed-segments -o /home/claude/.config/starship.toml \
    && echo 'eval "$(starship init bash)"' >> /home/claude/.bashrc

## Claude Code: install
ENV PATH="/home/claude/.local/bin:${PATH}"
RUN curl -fsSL https://claude.ai/install.sh | bash

## Claude Code: plugins
### Official Anthropics plugins
RUN claude plugin marketplace add anthropics/claude-plugins-official
RUN claude plugin install superpowers@claude-plugins-official \
    && claude plugin install firecrawl@claude-plugins-official \
    && claude plugin install frontend-design@claude-plugins-official \
    && claude plugin install playwright@claude-plugins-official \
    && claude plugin install pyright-lsp@claude-plugins-official \
    && claude plugin install typescript-lsp@claude-plugins-official \
    && claude plugin install code-review@claude-plugins-official \
    && claude plugin install commit-commands@claude-plugins-official \
    && claude plugin install code-simplifier@claude-plugins-official \
    && claude plugin install context7@claude-plugins-official \
    && claude plugin install claude-md-management@claude-plugins-official \
    && claude plugin install explanatory-output-style@claude-plugins-official \
    && claude plugin install learning-output-style@claude-plugins-official \
    && claude plugin install claude-code-setup@claude-plugins-official \
    && claude plugin install feature-dev@claude-plugins-official \
    && claude plugin install security-guidance@claude-plugins-official \
    && claude plugin install github@claude-plugins-official

HEALTHCHECK --interval=30s --timeout=5s CMD claude --version || exit 1

WORKDIR /home/claude/project
ENTRYPOINT ["/entrypoint.sh"]

# --- FULL: base + private plugins ---
FROM base AS full

### Private plugins
COPY --chmod=755 --chown=claude:claude private-build/claude-plugins.sh /tmp/claude-plugins.sh
RUN --mount=type=ssh \
    export SSH_AUTH_SOCK=$(ls /run/buildkit/ssh_agent.* 2>/dev/null | head -1) \
    && sudo chmod 666 /run/buildkit/ssh_agent.* \
    && bash /tmp/claude-plugins.sh \
    && rm -f /tmp/claude-plugins.sh

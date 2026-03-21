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

## User: remove default node user, create claude user
RUN userdel -r node
RUN useradd -m -s /bin/bash -u 1000 claude
RUN mkdir -p /home/claude/.config /home/claude/.local/bin /home/claude/.ssh /home/claude/project
RUN echo "claude ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/claude

## SSH: known hosts
COPY ssh/known_hosts /home/claude/.ssh/known_hosts
RUN chmod 700 /home/claude/.ssh
RUN chmod 644 /home/claude/.ssh/known_hosts

## Claude Code: config directories and files
RUN mkdir -p /home/claude/.claude
COPY claude/.claude.json /home/claude/.claude.json
COPY claude/settings.json /home/claude/.claude/settings.json

## Finalize root: fix ownership
RUN chown -R claude:claude /home/claude

## Entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# --- USER OPERATIONS ---
USER claude

## Shell: Starship prompt
RUN curl -sS https://starship.rs/install.sh | sh -s -- -y

## Shell: Starship config
RUN starship preset bracketed-segments -o /home/claude/.config/starship.toml
RUN echo 'eval "$(starship init bash)"' >> /home/claude/.bashrc

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
 && claude plugin install security-guidance@claude-plugins-official

### Private plugins
COPY --chown=claude:claude private-build/claude-plugins.sh /tmp/claude-plugins.sh
RUN chmod +x /tmp/claude-plugins.sh
RUN --mount=type=ssh sudo chmod 777 /run/buildkit/ssh_agent.* && bash /tmp/claude-plugins.sh
RUN rm -f /tmp/claude-plugins.sh

WORKDIR /home/claude/project
ENTRYPOINT ["/entrypoint.sh"]

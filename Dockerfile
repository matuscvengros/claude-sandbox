# Global ARG: controls which image the 'private' stage builds on.
# - "base"               → build everything locally (default)
# - "ghcr.io/user/repo"  → pull pre-built public image, skip local base build
ARG BASE_IMAGE=base

# ===========================================================================
# Base image
# ===========================================================================
FROM node:24 AS base

ARG DEBIAN_FRONTEND=noninteractive

# ===========================================================================
# Root operations
# ===========================================================================

# -- System Packages --------------------------------------------------------
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
    # Utilities \
    sox \
    && rm -rf /var/lib/apt/lists/*

# -- npm: Upgrade to Latest -------------------------------------------------
RUN npm install -g npm@latest

# -- Python Tools -----------------------------------------------------------
## uv: fast Python package manager
## pytest: testing framework
## ruff: fast linter & formatter (replaces flake8, black, isort)
## pyright: static type checker for Python
## pint: physical units library
## engunits: engineering units conversion library
## scipy: scientific computing (optimization, linear algebra, signal processing)
## numpy: numerical computing
## pandas: data manipulation & analysis
## matplotlib: plotting & visualization
## requests: HTTP client
## httpx: modern async HTTP client
## pydantic: data validation using type hints
RUN pip install --break-system-packages \
    uv pytest ruff pyright pint engunits \
    scipy numpy pandas matplotlib \
    requests httpx pydantic

# -- Rust Toolchain ---------------------------------------------------------
## rustup: Rust toolchain installer (stable channel)
## Includes: rustc, cargo, rustfmt, clippy
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH="/usr/local/cargo/bin:${PATH}"
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --default-toolchain stable --profile default \
    && chmod -R a+w $RUSTUP_HOME $CARGO_HOME

# -- Locale -----------------------------------------------------------------
RUN sed -i '/en_US.UTF-8/s/^# //' /etc/locale.gen \
 && locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# -- User Setup -------------------------------------------------------------
## Remove default node user, create claude user
RUN userdel -r node \
    && useradd -m -s /bin/bash -u 1000 claude \
    && mkdir -p /home/claude/.config /home/claude/.local/bin /home/claude/.ssh /home/claude/.claude \
    && chmod 700 /home/claude/.ssh \
    && echo "claude ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/claude

# -- SSH --------------------------------------------------------------------
COPY --chmod=644 ssh/known_hosts /home/claude/.ssh/known_hosts

# -- Finalize Root ----------------------------------------------------------
RUN chown -R claude:claude /home/claude

# ===========================================================================
# User operations
# ===========================================================================
USER claude

# -- Claude Code Config -----------------------------------------------------
COPY --chown=claude:claude claude/.claude.json /home/claude/.claude.json
COPY --chown=claude:claude claude/settings.json /home/claude/.claude/settings.json

# -- Shell: Starship Prompt -------------------------------------------------
RUN curl -sS https://starship.rs/install.sh | sh -s -- -y \
    && starship preset bracketed-segments -o /home/claude/.config/starship.toml \
    && echo 'eval "$(starship init bash)"' >> /home/claude/.bashrc

# -- Claude Code: install ---------------------------------------------------
ENV PATH="/home/claude/.local/bin:${PATH}"
RUN curl -fsSL https://claude.ai/install.sh | bash

# -- Claude Code: Plugins ---------------------------------------------------
## QOL
RUN npx claude-statusline-atomic@latest install

## Tools
RUN sudo npm install -g firecrawl-cli

## Official Marketplace
RUN claude plugin marketplace add anthropics/claude-plugins-official

## Claude Workflow & Configuration
RUN claude plugin install superpowers@claude-plugins-official \
    && claude plugin install claude-md-management@claude-plugins-official \
    && claude plugin install claude-code-setup@claude-plugins-official \
    && claude plugin install explanatory-output-style@claude-plugins-official \
    && claude plugin install learning-output-style@claude-plugins-official \
    && claude plugin install commit-commands@claude-plugins-official \
    && claude plugin install hookify@claude-plugins-official \
    && claude plugin install security-guidance@claude-plugins-official \
    ## Plugin & Skill Development
    && claude plugin install agent-sdk-dev@claude-plugins-official \
    && claude plugin install mcp-server-dev@claude-plugins-official \
    && claude plugin install plugin-dev@claude-plugins-official \
    && claude plugin install skill-creator@claude-plugins-official \
    ## Code Quality & Development
    && claude plugin install code-review@claude-plugins-official \
    && claude plugin install code-simplifier@claude-plugins-official \
    && claude plugin install pr-review-toolkit@claude-plugins-official \
    && claude plugin install feature-dev@claude-plugins-official \
    && claude plugin install pyright-lsp@claude-plugins-official \
    && claude plugin install typescript-lsp@claude-plugins-official \
    && claude plugin install clangd-lsp@claude-plugins-official \
    && claude plugin install frontend-design@claude-plugins-official \
    ## External Tools & Integrations
    && claude plugin install firecrawl@claude-plugins-official \
    && claude plugin install playwright@claude-plugins-official \
    && claude plugin install context7@claude-plugins-official \
    && claude plugin install github@claude-plugins-official

# -- Healthcheck ------------------------------------------------------------
HEALTHCHECK --interval=30s --timeout=5s CMD claude --version || exit 1

# -- Scripts -------------------------------------------------------------
## Entrypoint
COPY --chmod=755 scripts/entrypoint.sh /entrypoint.sh

## Credentials
COPY --chmod=755 --chown=claude:claude scripts/setup-credentials.sh /tmp/setup-credentials.sh

## Trust
COPY --chmod=755 --chown=claude:claude scripts/setup-claude-workdir-trust.sh /tmp/setup-claude-workdir-trust.sh

WORKDIR /home/claude/project
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]

# ===========================================================================
# Full: base + private plugins
# ===========================================================================
FROM ${BASE_IMAGE} AS private

# -- Private Plugins --------------------------------------------------------
COPY --chmod=755 --chown=claude:claude private/claude-plugins.sh /tmp/claude-plugins.sh
RUN --mount=type=ssh \
    export SSH_AUTH_SOCK=$(ls /run/buildkit/ssh_agent.* 2>/dev/null | head -1) \
    && sudo chmod 666 /run/buildkit/ssh_agent.* \
    && bash /tmp/claude-plugins.sh \
    && rm -f /tmp/claude-plugins.sh

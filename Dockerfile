# ===========================================================================
# Node 24 (copied into the final image via multi-stage)
# ===========================================================================
FROM node:24-bookworm AS node-src

# ===========================================================================
# Main Image
# ===========================================================================
FROM python:3.14-bookworm

LABEL org.opencontainers.image.title="agent-sandbox"

ARG DEBIAN_FRONTEND=noninteractive

# ===========================================================================
# Root Operations
#
# Ordered by setup dependency: base system tools first, then language
# runtimes/tooling, then user-scoped agent CLIs and plugins.
# ===========================================================================

# -- System Packages --------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build tools
    build-essential gcc g++ make cmake \
    # Version control & networking
    git gh curl wget ca-certificates gnupg openssh-client \
    # CLI utilities
    ripgrep fd-find jq unzip \
    # System
    sudo locales socat \
    # Utilities \
    sox \
    # Editors \
    vim \
    && rm -rf /var/lib/apt/lists/*

# -- Locale -----------------------------------------------------------------
RUN sed -i '/en_US.UTF-8/s/^# //' /etc/locale.gen \
 && locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# -- Node 24 (from official image) ------------------------------------------
## Copied from the current Node 24 multi-stage build. Python is the base image
## (it ships pip, shared libs, and the stdlib), so only the Node binary and its
## bundled node_modules (npm, npx, corepack) need grafting in.
COPY --from=node-src /usr/local/bin/node /usr/local/bin/node
COPY --from=node-src /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js       /usr/local/bin/npm \
 && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js       /usr/local/bin/npx \
 && ln -s /usr/local/lib/node_modules/corepack/dist/corepack.js /usr/local/bin/corepack

# -- npm: Fresh Upgrade -----------------------------------------------------
RUN npm install -g npm

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
RUN pip install --no-cache-dir \
    uv pytest ruff pyright \
    pint engunits \
    scipy numpy pandas matplotlib \
    requests httpx pydantic

# -- Global npm Tools -------------------------------------------------------
## typescript-language-server: LSP wrapper for tsserver
## firecrawl-cli: Firecrawl web-scraping CLI (companion to the firecrawl plugin)
RUN npm install -g \
    typescript-language-server \
    firecrawl-cli

# -- Rust Toolchain ---------------------------------------------------------
## rustup: Rust toolchain installer (latest stable channel)
## Includes: rustc, cargo, rustfmt, clippy, rust-analyzer
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH="/usr/local/cargo/bin:${PATH}"
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --profile default \
    && chmod -R a+w $RUSTUP_HOME $CARGO_HOME \
    && rustup component add rust-analyzer

# -- User Setup -------------------------------------------------------------
## Create agent user (UID 1000). The Python base image ships no
## non-root user, so UID 1000 is free.
RUN useradd -m -s /bin/bash -u 1000 agent \
    && mkdir -p /home/agent/.config /home/agent/.ssh /home/agent/.claude \
    && chmod 700 /home/agent/.ssh \
    && echo "agent ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/agent \
    && chmod 0440 /etc/sudoers.d/agent

# -- SSH --------------------------------------------------------------------
COPY --chmod=644 ssh/known_hosts /home/agent/.ssh/known_hosts

# -- Finalize Root ----------------------------------------------------------
RUN chown -R agent:agent /home/agent

# ===========================================================================
# User Operations
#
# Everything from here runs as the agent user.
# ===========================================================================
USER agent

# -- Per-user npm prefix ----------------------------------------------------
## Install npm globals under /home/agent/.npm-global so each AI-agent CLI
## below can be installed as `agent` without sudo. Binaries land in
## ~/.npm-global/bin which we prepend to PATH.
##
## Note: ENV is image-wide, not USER-scoped. These vars persist to runtime
## and to any future `USER root` layer below, so a subsequent root-level
## `npm install -g` would also target /home/agent/.npm-global unless it
## overrides NPM_CONFIG_PREFIX inline.
ENV NPM_CONFIG_PREFIX=/home/agent/.npm-global \
    PATH="/home/agent/.npm-global/bin:${PATH}"

# -- Shell: Starship Prompt -------------------------------------------------
RUN curl -sS https://starship.rs/install.sh | sh -s -- -y \
    && starship preset bracketed-segments -o /home/agent/.config/starship.toml \
    && echo 'eval "$(starship init bash)"' >> /home/agent/.bashrc

# -- Claude Code -----------------------------------------------------------

## -- Install --
RUN npm install -g @anthropic-ai/claude-code

## -- Onboarding State --
### Seeds onboarding/marketplace flags so `claude plugin install` below runs
### non-interactively. Must come before plugin installs, because those mutate
### this same file.
COPY --chown=agent:agent claude/.claude.json /home/agent/.claude.json

## -- Plugins --
### QOL
RUN npx --yes claude-statusline-atomic install

### Official Marketplace
RUN claude plugin marketplace add anthropics/claude-plugins-official

### Claude Workflow & Configuration
RUN claude plugin install superpowers@claude-plugins-official \
    && claude plugin install claude-md-management@claude-plugins-official \
    && claude plugin install claude-code-setup@claude-plugins-official \
    && claude plugin install explanatory-output-style@claude-plugins-official \
    && claude plugin install learning-output-style@claude-plugins-official \
    && claude plugin install commit-commands@claude-plugins-official \
    && claude plugin install hookify@claude-plugins-official \
    && claude plugin install security-guidance@claude-plugins-official \
    ### Plugin & Skill Development
    && claude plugin install agent-sdk-dev@claude-plugins-official \
    && claude plugin install mcp-server-dev@claude-plugins-official \
    && claude plugin install plugin-dev@claude-plugins-official \
    && claude plugin install skill-creator@claude-plugins-official \
    ### Code Quality & Development
    && claude plugin install code-review@claude-plugins-official \
    && claude plugin install code-simplifier@claude-plugins-official \
    && claude plugin install pr-review-toolkit@claude-plugins-official \
    && claude plugin install feature-dev@claude-plugins-official \
    && claude plugin install pyright-lsp@claude-plugins-official \
    && claude plugin install typescript-lsp@claude-plugins-official \
    && claude plugin install clangd-lsp@claude-plugins-official \
    && claude plugin install frontend-design@claude-plugins-official \
    ### External Tools & Integrations
    && claude plugin install firecrawl@claude-plugins-official \
    && claude plugin install playwright@claude-plugins-official \
    && claude plugin install context7@claude-plugins-official \
    && claude plugin install github@claude-plugins-official

## -- Runtime Settings --
COPY --chown=agent:agent claude/settings.json /home/agent/.claude/settings.json

# -- Codex -----------------------------------------------------------------
## OpenAI Codex: AI coding agent CLI
RUN npm install -g @openai/codex

# -- OpenCode --------------------------------------------------------------
## SST opencode: open-source AI coding agent
RUN npm install -g opencode-ai

# -- Pi --------------------------------------------------------------------
## Pi Coding Agent: minimal terminal coding harness supporting 15+ LLM providers
RUN npm install -g @mariozechner/pi-coding-agent

# ===========================================================================
# Finalize
# ===========================================================================

# -- Scripts ----------------------------------------------------------------
## Entrypoint
COPY --chmod=755 scripts/entrypoint.sh /entrypoint.sh
## Credentials
COPY --chmod=755 --chown=agent:agent scripts/setup-credentials.sh /tmp/setup-credentials.sh
## Trust
COPY --chmod=755 --chown=agent:agent scripts/setup-claude-workdir-trust.sh /tmp/setup-claude-workdir-trust.sh
COPY --chmod=755 --chown=agent:agent scripts/setup-codex-workdir-trust.sh /tmp/setup-codex-workdir-trust.sh

# -- Healthcheck ------------------------------------------------------------
HEALTHCHECK --interval=30s --timeout=5s CMD claude --version || exit 1

WORKDIR /home/agent
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]

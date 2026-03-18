#!/bin/bash
# Plugin setup script — run during Docker build to install official marketplace plugins.
# Custom plugins are handled via COPY in the Dockerfile.
#
# This script is a placeholder. Claude Code's plugin installation requires
# network access and an authenticated session, which may not be available
# at build time. The actual plugin installation strategy depends on how
# Claude Code's plugin CLI works in headless/non-interactive mode.
#
# Options for plugin installation:
# 1. If plugins can be installed via CLI at build time:
#    claude plugins install superpowers@claude-plugins-official
#    claude plugins install frontend-design@claude-plugins-official
#    claude plugins install firecrawl@claude-plugins-official
#    claude plugins install pyright-lsp@claude-plugins-official
#    claude plugins install typescript-lsp@claude-plugins-official
#
# 2. If not, copy the plugin cache from the host at build time:
#    COPY --from=host-plugins plugins/official/ /home/claude/.claude/plugins/cache/
#
# 3. Or install on first container run via entrypoint hook.

echo "Plugin setup placeholder — configure based on your plugin installation method."

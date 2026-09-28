#!/bin/sh
# Makes the API key saved in the plugin's settings (userConfig "api_key",
# stored in the system credential store) visible to Claude's Bash commands.
# Claude Code gives plugin hooks the saved value as CLAUDE_PLUGIN_OPTION_API_KEY
# and runs $CLAUDE_ENV_FILE before every Bash command. Nothing is sent anywhere
# and nothing is printed. Without a saved key or an env file this does nothing.
[ -n "${CLAUDE_PLUGIN_OPTION_API_KEY:-}" ] || exit 0
[ -n "${CLAUDE_ENV_FILE:-}" ] || exit 0
quoted=$(printf '%s' "$CLAUDE_PLUGIN_OPTION_API_KEY" | sed "s/'/'\\\\''/g")
printf "export CLAUDE_PLUGIN_OPTION_API_KEY='%s'\n" "$quoted" >> "$CLAUDE_ENV_FILE"
exit 0

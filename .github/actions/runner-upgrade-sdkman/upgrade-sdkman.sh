#!/usr/bin/env zsh

[[ -s "$SDKMAN_INIT" ]] && source "$SDKMAN_INIT"
sdk selfupdate force 2>/dev/null || { echo "upgraded=false" >> "$GITHUB_OUTPUT"; exit 0 }

printf '::notice title=SDKMAN upgraded::selfupdate complete\n'
echo "upgraded=true" >> "$GITHUB_OUTPUT"

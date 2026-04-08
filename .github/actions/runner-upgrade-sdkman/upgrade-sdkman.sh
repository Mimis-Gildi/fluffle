#!/usr/bin/env zsh

echo -e "## SDKMan Upgrade\n" >> $GITHUB_STEP_SUMMARY

export RUST_BACKTRACE=1
source "$SDKMAN_INIT"

sdk current
sdk version

sdk selfupdate 2>/dev/null || {
  echo "upgraded=false" >> "$GITHUB_OUTPUT";
  echo "SDKMan is NOT self-updated." >> $GITHUB_STEP_SUMMARY
  exit 0 }

printf '::notice title=SDKMAN upgraded::selfupdate is completed.\n'
sdk version 2>/dev/null >> $GITHUB_STEP_SUMMARY
echo "upgraded=true" >> "$GITHUB_OUTPUT"

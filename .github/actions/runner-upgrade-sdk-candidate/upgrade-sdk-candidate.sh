#!/usr/bin/env zsh

readonly candidate=$1

printf '## Upgrade %s\n' $candidate > $GITHUB_STEP_SUMMARY
print 'upgraded=false' > $GITHUB_OUTPUT

export RUST_BACKTRACE=1
source $SDKMAN_INIT

sdk current >&1
sdk version >&1
sdk update >&1

printf '\nProcessing %s\n' $candidate

declare -a installed=($(sdk list $candidate | awk '$1 ~ /^[>*+]$/ {for (i=1; i<=NF; i++) if ($i ~ /^[0-9]/) { print $i; break }}'))

for instance in $installed; do
  sdk uninstall $candidate $instance --force
  printf 'Removed %1$s %2$s\n' $candidate $instance
  printf '- uninstalled %s %s\n' $candidate $instance >> $GITHUB_STEP_SUMMARY
done

sdk flush --all >&1

sdkman_auto_answer=true sdk install $candidate

readonly outcome=$(sdk current $candidate >&1)

printf '\nOutcome: s\n' $outcome >> $GITHUB_STEP_SUMMARY
printf '::notice title=%1$s::%2$s\n' $candidate $outcome
print 'upgraded=true' > $GITHUB_OUTPUT

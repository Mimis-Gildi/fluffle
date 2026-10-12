#!/usr/bin/env zsh

readonly candidate=$1

printf '## Upgrade %s\n\n' $candidate > $GITHUB_STEP_SUMMARY
print 'upgraded=false' > $GITHUB_OUTPUT

source ${0:A:h}/../runner_support.sh

sdk_refresh

printf '\nProcessing %s\n' $candidate

declare -a installed=($(sdk_installed_versions_of_candidate $candidate))

for instance in $installed; do
  sdk uninstall $candidate $instance --force
  printf 'Removed %1$s %2$s\n' $candidate $instance
  printf '- uninstalled %s %s\n' $candidate $instance >> $GITHUB_STEP_SUMMARY
done

sdk flush --all

sdkman_auto_answer=true sdk install $candidate

readonly outcome=$(sdk current $candidate)

printf '\nOutcome: %s\n' $outcome >> $GITHUB_STEP_SUMMARY
printf '::notice title=%1$s::%2$s\n' $candidate $outcome
print 'upgraded=true' > $GITHUB_OUTPUT

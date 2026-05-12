#!/usr/bin/env zsh

readonly candidate=$1

printf '## Upgrade %s\n' $candidate > $GITHUB_STEP_SUMMARY
print 'upgraded=false' > $GITHUB_OUTPUT

export RUST_BACKTRACE=1
source $SDKMAN_INIT

sdk current
sdk version
sdk update

readonly actual=$(sdk current $candidate | awk '{ print $NF }')
readonly latest=$(sdk list $candidate | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | sort -V | tail -n1)

if [[ $actual != $latest ]]; then
  sdk install $candidate $latest
  sdk default $candidate $latest

  printf '### Set %s to %s\n\n' $candidate $latest >> $GITHUB_STEP_SUMMARY
  printf '::notice title=%s upgraded::%s -> %s\n' $candidate $actual $latest
  print 'upgraded=true' > $GITHUB_OUTPUT
fi

readonly local_off=$(sdk list $candidate | grep 'local only' | awk '{ print $NF }' | sort -V)
readonly installed=$(sdk list $candidate | grep 'installed' | awk '{ print $NF }' | sort -V)

for spare in ${(@f)local_off}; do
  sdk uninstall $candidate $spare
  printf '- uninstalled spare %s %s\n' $candidate $spare >> $GITHUB_STEP_SUMMARY
done

for shim in ${(@f)installed}; do
  if [[ $shim == $latest ]]; then
    printf '- skipping ACTIVE %s %s\n' $candidate $shim >> $GITHUB_STEP_SUMMARY
  else
    sdk uninstall $candidate $shim
    printf '- uninstalled %s %s\n' $candidate $shim >> $GITHUB_STEP_SUMMARY
  fi
done

{
  printf '### Final %s State:' $candidate

  sdk current $candidate

  sdk flush --all
} >> $GITHUB_STEP_SUMMARY

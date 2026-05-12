#!/usr/bin/env zsh

print '## Upgrade Java' > $GITHUB_STEP_SUMMARY
print 'upgraded=false' > $GITHUB_OUTPUT

export RUST_BACKTRACE=1
source $SDKMAN_INIT

sdk current
sdk version
sdk update

readonly actual=$(sdk current java | awk '{ print $NF }')
readonly latest=$(sdk list java | grep -oE '21\.[0-9.]+\-tem' | sort -V | tail -n1)


if [[ $actual != $latest ]]; then
  sdk install java $latest
  sdk default java $latest

  printf '### Set Java to %s\n\n' $latest >> $GITHUB_STEP_SUMMARY
  printf '::notice title=Java upgraded::%s -> %s\n' $actual $latest
  print 'upgraded=true' > $GITHUB_OUTPUT
fi

readonly local_off=$(sdk list java | grep 'local only'  | awk '{ print $NF }' | sort -V)
readonly installed=$(sdk list java | grep 'installed'   | awk '{ print $NF }' | sort -V)

for spare in ${(@f)local_off}; do
  sdk uninstall java $spare
  printf '- uninstalled spare Java %s\n' $spare >> $GITHUB_STEP_SUMMARY
done

for shim in ${(@f)installed}; do
  if [[ $shim == $latest ]]; then
    printf '- skipping ACTIVE Java %s\n' $shim >> $GITHUB_STEP_SUMMARY
  else
    sdk uninstall java $shim
    printf '- uninstalled current Java %s\n' $shim >> $GITHUB_STEP_SUMMARY
  fi
done

{
  print '### Final Java State:'

  sdk current java
  sdk flush --all
} >> $GITHUB_STEP_SUMMARY

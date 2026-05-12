#!/usr/bin/env zsh

print '## SDKMan Upgrade' > $GITHUB_STEP_SUMMARY

export RUST_BACKTRACE=1
source $SDKMAN_INIT

sdk current
sdk version
sdk update
sdk flush --all

sdk selfupdate || {
  print 'upgraded=false' > $GITHUB_OUTPUT
  print '### ERROR: SDKMan did NOT self-update.' >> $GITHUB_STEP_SUMMARY
  exit 0
}

print '::notice title=SDKMAN upgraded::selfupdate is completed.'
sdk version >> $GITHUB_STEP_SUMMARY
print 'upgraded=true' > $GITHUB_OUTPUT

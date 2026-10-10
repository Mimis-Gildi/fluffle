#!/usr/bin/env zsh

print 'completed=false' > $GITHUB_OUTPUT

readonly action_home=${0:A:h}
source $action_home/conda-remove.sh
source $action_home/conda-install.sh
source $action_home/conda-ml.sh

conda_remove

remaining=$(conda_remove_remaining)
[[ -n $remaining ]] && {
  printf '::error title=Conda leftovers::%s files survived rip out\n' ${#${(f)remaining}}
  printf '### Conda leftovers\n\n```text\n%s\n```\n\n' $remaining >> $GITHUB_STEP_SUMMARY
}

conda_install

conda_ml

printf '### Conda installed\n\n```text\n%s\n```\n\n' "$(conda info)" >> $GITHUB_STEP_SUMMARY

print 'completed=true' > $GITHUB_OUTPUT

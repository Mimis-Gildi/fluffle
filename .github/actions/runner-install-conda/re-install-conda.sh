#!/usr/bin/env zsh

print 'completed=false' > $GITHUB_OUTPUT

readonly action_home=${0:A:h}
source $action_home/../runner_support.sh
source $action_home/../conda-support.sh
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

readonly activation=$action_home/../conda-activate.sh
[[ -s $activation ]] && source $activation
(( $+functions[conda] )) || run_error "conda not activated" 111
(( $+functions[mamba] )) || run_error "mamba not activated" 112

conda_ml $1 $2

printf '### Conda installed\n\n```text\n%s\n```\n\n' "$(conda info)" >> $GITHUB_STEP_SUMMARY

print 'completed=true' > $GITHUB_OUTPUT

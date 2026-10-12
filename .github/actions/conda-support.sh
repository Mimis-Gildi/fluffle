#!/usr/bin/env zsh

readonly conda_home=$HOME/miniforge3
readonly conda_bin=$conda_home/bin
readonly conda_which=$conda_bin/conda
readonly mamba_which=$conda_bin/mamba

conda_info() {
  local info=$(conda info)
  printf '### %s: shell level %s, env %s\n\n```\n%s\n```\n\n' $1 ${CONDA_SHLVL:-none} ${CONDA_DEFAULT_ENV:-none} $info >> $GITHUB_STEP_SUMMARY
  print -r -- $info
}

#!/usr/bin/env zsh

readonly py_ml_required=${1:-0}
readonly conda_required=${2:-0}
readonly mamba_required=${3:-0}

behind() { [[ $(printf '%s\n%s' $1 $2 | sort -V | head -n1) != $1 ]] }

hosed() {
  printf '::error title=Conda is hosed::%s\n' $1
  print 'hosed=true' > $GITHUB_OUTPUT
  exit 0
}

readonly conda_bin=$HOME/miniforge3/bin/conda
readonly mamba_bin=$HOME/miniforge3/bin/mamba
[[ -x $conda_bin ]] || hosed "no conda at $conda_bin"
[[ -x $mamba_bin ]] || hosed "no mamba at $mamba_bin"

readonly activation=${0:A:h}/conda-activate.sh
[[ -s $activation ]] && source $activation
(( $+functions[conda] )) || hosed "conda not activated"
(( $+functions[mamba] )) || hosed "mamba not activated"

readonly conda_version=$(conda --version | awk '/^conda/ { print $2 }')
readonly mamba_version=$(mamba --version)
[[ -n $conda_version ]] || hosed "conda --version gives no version"
[[ -n $mamba_version ]] || hosed "mamba --version gives no version"

channels=$(conda config --show channels) || hosed "conda config --show channels failed"
[[ $(print -r -- $channels | awk '/^ *- / { print $2 }') == conda-forge ]] || hosed "channels are not exactly [conda-forge]"

priority=$(conda config --show channel_priority) || hosed "conda config --show channel_priority failed"
[[ $(print -r -- $priority | awk '{ print $2 }') == strict ]] || hosed "channel_priority is not strict"

sources=$($conda_bin config --show-sources) || hosed "conda config --show-sources failed"
readonly foreign_sources=$(print -r -- $sources | awk -v own="$HOME/.condarc" '/^==> / && $2 != own { print $2 }')
[[ -z $foreign_sources ]] || hosed "config sources other than ~/.condarc: ${foreign_sources//$'\n'/ }"

ml_list=$($conda_bin list -n ml) || hosed "conda list -n ml failed"
readonly ml_core=$(print -r -- $ml_list | awk '!/^#/ && $1 ~ /^conda/ { print $1 }')
[[ -z $ml_core ]] || hosed "conda core in ml: ${ml_core//$'\n'/ }"
readonly ml_foreign=$(print -r -- $ml_list | awk '!/^#/ && $4 != "conda-forge" { print $1 "(" $4 ")" }')
[[ -z $ml_foreign ]] || hosed "ml packages not from conda-forge: ${ml_foreign//$'\n'/ }"

conda activate ml || hosed "conda activate ml failed"

readonly py_ml_version=$(python --version | awk '/^Python/ { print $2 }')

if behind $py_ml_required $py_ml_version || behind $conda_required $conda_version || behind $mamba_required $mamba_version; then
  printf '::warning title=Conda is behind::Python %s (%s), Conda %s (%s), Mamba %s (%s)\n' \
    $py_ml_version $py_ml_required $conda_version $conda_required $mamba_version $mamba_required
  print 'failed=true' > $GITHUB_OUTPUT
else
  printf '::notice title=Python Stack OK::Python %s, Conda %s, Mamba %s\n' $py_ml_version $conda_version $mamba_version
fi

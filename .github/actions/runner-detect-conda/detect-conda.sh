#!/usr/bin/env zsh

readonly py_base_required=${1:-0}
readonly py_ml_required=${2:-0}
readonly conda_required=${3:-0}
readonly mamba_required=${4:-0}

readonly conda_home=$HOME/miniforge3
readonly conda_bin=$conda_home/bin
readonly conda_which=$conda_bin/conda
readonly mamba_which=$conda_bin/mamba

behind() { [[ $(printf '%s\n%s' $1 $2 | sort -V | head -n1) != $1 ]] }

hosed() {
  printf '::error title=Conda is hosed::%s\n' $1
  print 'hosed=true' > $GITHUB_OUTPUT
  exit 0
}

conda_info() {
  local info=$(conda info)
  printf '### %s: shell level %s, env %s\n\n```\n%s\n```\n\n' $1 ${CONDA_SHLVL:-none} ${CONDA_DEFAULT_ENV:-none} $info >> $GITHUB_STEP_SUMMARY
  print -r -- $info
}

[[ -x $conda_which ]] || hosed "no conda at $conda_which"
[[ -x $mamba_which ]] || hosed "no mamba at $mamba_which"

printf '::notice title=Conda at job init::shell level %s, env %s\n' ${CONDA_SHLVL:-none} ${CONDA_DEFAULT_ENV:-none}

readonly activation=${0:A:h}/conda-activate.sh
[[ -s $activation ]] && source $activation
(( $+functions[conda] )) || hosed "conda not activated"
(( $+functions[mamba] )) || hosed "mamba not activated"

printf '::notice title=Conda after activation hook::shell level %s, env %s\n' ${CONDA_SHLVL:-none} ${CONDA_DEFAULT_ENV:-none}
conda_info 'Conda after activation hook' > /dev/null

readonly conda_base=$(conda info --base)
[[ $conda_base == $conda_home ]] || hosed "conda base is ${conda_base:-none}, expected $conda_home"

readonly conda_version=$(conda --version | awk '/^conda/ { print $2 }')
readonly mamba_version=$(mamba --version)
[[ -n $conda_version ]] || hosed "conda --version gives no version"
[[ -n $mamba_version ]] || hosed "mamba --version gives no version"

channels=$(conda config --show channels) || hosed "conda config --show channels failed"
[[ -n $(print -r -- $channels | awk '/^ *- / && $2 == "conda-pypi"') ]] && {
  printf '::warning title=Conda channels drift::conda-pypi channel present\n'
  print 'failed=true' > $GITHUB_OUTPUT
}

priority=$(conda config --show channel_priority) || hosed "conda config --show channel_priority failed"
[[ $(print -r -- $priority | awk '{ print $2 }') == strict ]] || {
    printf '::warning title=Conda priority drift::channel_priority is not strict\n'
    print 'failed=true' > $GITHUB_OUTPUT
}

while (( CONDA_SHLVL > 1 )); do
  conda deactivate
  printf '::notice title=Conda deactivate::shell level %s, env %s\n' ${CONDA_SHLVL:-none} ${CONDA_DEFAULT_ENV:-none}
  conda_info 'Conda deactivate' > /dev/null
done
readonly base_info=$(conda_info 'Conda base')
readonly base_location=$(print -r -- $base_info | awk -F' : ' '/active env location/ { print $2 }')
[[ $base_location == $conda_home ]] || hosed "conda deactivate lands in ${base_location:-none}, expected $conda_home"

readonly py_base_version=$(python --version | awk '/^Python/ { print $2 }')
[[ -n $py_base_version ]] || hosed "python --version in base gives no version"
[[ $py_base_version == 3.12.* ]] && hosed "base Python $py_base_version pinned to 3.12, base must be recreated"

behind $py_base_required $py_base_version && {
  printf '::warning title=Python is behind::base Python %s, floor %s\n' $py_base_version $py_base_required
  print 'failed=true' > $GITHUB_OUTPUT
}

behind $conda_required $conda_version && {
  printf '::warning title=Conda is behind::Conda %s, floor %s\n' $conda_version $conda_required
  print 'failed=true' > $GITHUB_OUTPUT
}

behind $mamba_required $mamba_version && {
  printf '::warning title=Mamba is behind::Mamba %s, floor %s\n' $mamba_version $mamba_required
  print 'failed=true' > $GITHUB_OUTPUT
}

envs=$(conda env list) || hosed "conda env list failed"
if [[ -n $(print -r -- $envs | awk '$1 == "ml"') ]]; then
  ml_packages=$(conda list -n ml) || hosed "conda list -n ml failed"
  [[ -n $(print -r -- $ml_packages | awk '$1 == "conda"') ]] && hosed "conda core installed in ml, base must be recreated"
  conda activate ml
  if [[ $(conda_info 'Conda ml' | awk -F' : ' '/active environment/ { print $2 }') == ml ]]; then
    readonly py_ml_version=$(python --version | awk '/^Python/ { print $2 }')
    behind $py_ml_required ${py_ml_version:-0.0.0} && {
      printf '::warning title=Python is behind::ml Python %s, floor %s\n' ${py_ml_version:-none} $py_ml_required
      print 'failed=true' > $GITHUB_OUTPUT
    }
  else
    hosed 'ml exists but does not activate'
  fi
else
  printf '::warning title=Conda ml missing::no ml environment\n'
  print 'failed=true' > $GITHUB_OUTPUT
fi

printf '::notice title=Conda stack::base Python %s, ml Python %s, Conda %s, Mamba %s\n' $py_base_version ${py_ml_version:-none} $conda_version $mamba_version

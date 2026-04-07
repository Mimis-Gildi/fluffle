#!/usr/bin/env zsh

readonly py_ml_version="$1"
readonly conda_version="$2"
readonly mamba_version="$3"

readonly activation="${0:A:h}/conda-activate.sh"
[[ -s "$activation" ]] && source "$activation"

conda activate ml || exit 0

readonly py_ml_version=$(python --version 2>/dev/null | awk '/^Python/ { print $2 }') || exit 0  # Python 3.12.13
readonly conda_version=$(conda  --version 2>/dev/null  | awk '/^conda/ { print $2 }') || exit 0  # conda 26.1.1
readonly mamba_version=$(mamba  --version 2>/dev/null) || exit 0  # 2.3.3


printf '::warning title=Python Versions::py_ml=<%s>, conda=<%s>, mamba=<%s>\n' "$py_ml_version" "$conda_version" "$mamba_version"


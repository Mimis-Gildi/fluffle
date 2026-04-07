#!/usr/bin/env zsh

readonly py_ml_version="$1"
readonly conda_version="$2"
readonly mamba_version="$3"

source "${0:A:h}/conda-activate.sh"

conda activate ml

readonly py_ml_version_output=$(python --version 2>/dev/null) || exit 0  # Python 3.12.13
readonly conda_version_output=$(conda  --version 2>/dev/null) || exit 0  # conda 26.1.1
readonly mamba_version_output=$(mamba  --version 2>/dev/null) || exit 0  # 2.3.3

readonly py_ml_actual=$(echo "$py_ml_version_output" | awk '/^Python/ { print $2 }')
readonly conda_actual=$(echo "$conda_version_output" | awk '/^conda/ { print $2 }')

printf '::warning title=Python Versions::py=<%s.%s>, co=<%s.%s>, ma=<%s>\n' "$py_ml_version" "$py_ml_actual" "$conda_version_output" "$conda_actual" "$mamba_version_output"


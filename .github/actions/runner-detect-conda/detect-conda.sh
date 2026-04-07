#!/usr/bin/env zsh

behind() { [[ "$(printf '%s\n%s' "$1" "$2" | sort -V | head -n1)" != "$1" ]] }

readonly py_ml_required="${1:-0}"
readonly conda_required="${2:-0}"
readonly mamba_required="${3:-0}"

readonly activation="${0:A:h}/conda-activate.sh"
[[ -s "$activation" ]] && source "$activation"

conda activate ml || exit 0

readonly py_ml_version=$(python --version 2>/dev/null | awk '/^Python/ { print $2 }') || exit 0  # Python 3.12.13
readonly conda_version=$(conda  --version 2>/dev/null  | awk '/^conda/ { print $2 }') || exit 0  # conda 26.1.1
readonly mamba_version=$(mamba  --version 2>/dev/null) || exit 0  # 2.3.3

if behind "$py_ml_required" "$py_ml_version" || behind "$conda_required" "$conda_version" || behind "$mamba_required" "$mamba_version"; then
  printf '::warning title=Conda is behind::Python %s (%s), Conda %s (%s), Mamba %s (%s)\n' \
    "$py_ml_version" "$py_ml_required" "$conda_version" "$conda_required" "$mamba_version" "$mamba_required"
  echo "failed=true" > "$GITHUB_OUTPUT"
fi

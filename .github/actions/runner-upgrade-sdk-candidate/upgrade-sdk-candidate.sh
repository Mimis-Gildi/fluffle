#!/usr/bin/env zsh

readonly candidate="$1"

echo -e "## Upgrade $candidate\n" >> $GITHUB_STEP_SUMMARY
echo "upgraded=false" > "$GITHUB_OUTPUT"

export RUST_BACKTRACE=1
source "$SDKMAN_INIT"

sdk current
sdk version
sdk update

readonly actual=$(sdk current "$candidate" 2>/dev/null | awk '{ print $NF }') || exit 0
readonly latest=$(sdk list "$candidate" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | sort -V | tail -n1) || exit 0

if [[ "$actual" != "$latest" ]]; then
  sdk install "$candidate" "$latest"
  sdk default "$candidate" "$latest"

  echo "Set $candidate to $latest" >> $GITHUB_STEP_SUMMARY
  printf '::notice title=%s upgraded::%s -> %s\n' "$candidate" "$actual" "$latest"
  echo "upgraded=true" > "$GITHUB_OUTPUT"
fi

readonly local_off=$(sdk list "$candidate" 2>/dev/null | grep 'local only' | awk '{ print $NF }' | sort -V) || true
readonly installed=$(sdk list "$candidate" 2>/dev/null | grep 'installed' | awk '{ print $NF }' | sort -V) || true

for spare in ${(@f)local_off}; do
  sdk uninstall "$candidate" "$spare"
  echo "Uninstalled spare $candidate $spare" >> $GITHUB_STEP_SUMMARY
done

for shim in ${(@f)installed}; do
  if [[ "$shim" == "$latest" ]]; then
    echo "Skipping ACTIVE $candidate $shim" >> $GITHUB_STEP_SUMMARY
  else
    sdk uninstall "$candidate" "$shim"
    echo "Uninstalled $candidate $shim" >> $GITHUB_STEP_SUMMARY
  fi
done

sdk current "$candidate" 2>/dev/null >> $GITHUB_STEP_SUMMARY

sdk flush tmp >> $GITHUB_STEP_SUMMARY
sdk flush metadata >> $GITHUB_STEP_SUMMARY
sdk flush version >> $GITHUB_STEP_SUMMARY

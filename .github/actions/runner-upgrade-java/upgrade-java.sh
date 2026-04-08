#!/usr/bin/env zsh

echo -e "## Upgrade Java\n" >> $GITHUB_STEP_SUMMARY

echo "upgraded=false" > "$GITHUB_OUTPUT"
source "$SDKMAN_INIT"

sdk update

readonly actual=$(sdk current java 2>/dev/null  | awk '{ print $NF }') || exit 0
readonly latest=$(sdk list java 2>/dev/null     | grep -oE '21\.[0-9.]+\-tem' | sort -V | tail -n1) || exit 0


if [[ "$actual" != "$latest" ]]; then
  sdk install java "$latest"
  sdk default java "$latest"

  echo "Set Java to $latest" >> $GITHUB_STEP_SUMMARY
  printf '::notice title=Java upgraded::%s -> %s\n' "$actual" "$latest"
  echo "upgraded=true" > "$GITHUB_OUTPUT"
fi

readonly local_off=$(sdk list java 2>/dev/null | grep 'local only'  | awk '{ print $NF }' | sort -V) || exit 0
readonly installed=$(sdk list java 2>/dev/null | grep 'installed'   | awk '{ print $NF }' | sort -V) || exit 0

for spare in ${(@f)local_off}; do
  sdk uninstall java "$spare"
  echo "Uninstalled spare Java $spare" >> $GITHUB_STEP_SUMMARY
done


for shim in ${(@f)installed}; do
  if [[ "$shim" == "$latest" ]]; then
    echo "Skipping ACTIVE Java $shim" >> $GITHUB_STEP_SUMMARY
  else
    sdk uninstall java "$shim"
    echo "Uninstalled current Java $shim" >> $GITHUB_STEP_SUMMARY
  fi
done

sdk current java 2>/dev/null >> $GITHUB_STEP_SUMMARY

sdk flush tmp >> $GITHUB_STEP_SUMMARY
sdk flush metadata >> $GITHUB_STEP_SUMMARY
sdk flush version >> $GITHUB_STEP_SUMMARY

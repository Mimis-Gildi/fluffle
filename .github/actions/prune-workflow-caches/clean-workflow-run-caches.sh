#!/usr/bin/env zsh
set -uo pipefail

readonly repository="${REPO:-$(basename "$(git rev-parse --show-toplevel)")}"
readonly branch="${BRANCH:-$(git rev-parse --abbrev-ref HEAD)}"
echo "::notice title=Cache Pruner::Starting GH CLI cache pruning in <$repository>"
echo "::notice title=Active Branch::<$branch>"

declare -i skipped=0 deleted=0 failed=0
declare -i pass_deleted=0

echo "## Workflow Cache Pruner" >> $GITHUB_STEP_SUMMARY
echo "" >> $GITHUB_STEP_SUMMARY
echo "**Repository:** \`$repository\` | **Branch:** \`$branch\`" >> $GITHUB_STEP_SUMMARY
echo "" >> $GITHUB_STEP_SUMMARY
echo "| Cache ID | Size | Branch | Age | Action |" >> $GITHUB_STEP_SUMMARY
echo "|----------|------|--------|-----|--------|" >> $GITHUB_STEP_SUMMARY

function prune_one_pass() {
  pass_deleted=0
  while IFS= read -r cache_entry_row; do
    read -r id size scale ref age age_scale passe <<< "$cache_entry_row"
    [[ -z "${id//}" ]] && continue

    if [[ "$age_scale" == "minutes" || "$age_scale" == "minute" ]]; then
      (( skipped++ ))
      echo "| $id | $size $scale | $ref | $age $age_scale | skipped (recent) |" >> $GITHUB_STEP_SUMMARY
    else
      if gh actions-cache delete "$id" --confirm 2>/dev/null; then
        (( deleted++ ))
        (( pass_deleted++ ))
        echo "| $id | $size $scale | $ref | $age $age_scale | deleted |" >> $GITHUB_STEP_SUMMARY
      else
        (( failed++ ))
        echo "| $id | $size $scale | $ref | $age $age_scale | **failed** |" >> $GITHUB_STEP_SUMMARY
      fi
    fi
  done < <(gh actions-cache list --order desc --limit 100)
}

declare -i pass=0
while true; do
  (( pass++ ))
  echo "::group::Cache prune pass $pass"
  prune_one_pass
  echo "::endgroup::"
  if (( pass_deleted == 0 )); then
    echo "::notice title=Pass $pass::Nothing left to prune."
    break
  fi
  echo "::notice title=Pass $pass::Deleted $pass_deleted, continuing."
done

# Summary
echo "" >> $GITHUB_STEP_SUMMARY
echo "**Passes:** $pass | **Deleted:** $deleted | **Skipped:** $skipped | **Failed:** $failed" >> $GITHUB_STEP_SUMMARY

echo "::notice title=Cache Pruning Complete::$pass passes, deleted $deleted, skipped $skipped (recent), failed $failed"

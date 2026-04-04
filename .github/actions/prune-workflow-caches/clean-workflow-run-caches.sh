#!/usr/bin/env zsh
set -uo pipefail

readonly repository="${REPO:-$(basename "$(git rev-parse --show-toplevel)")}"
readonly branch="${BRANCH:-$(git rev-parse --abbrev-ref HEAD)}"
echo "::notice title=Cache Pruner::Starting GH CLI cache pruning in <$repository>"
echo "::notice title=Active Branch::<$branch>"

declare -i skipped=0 deleted=0 failed=0
readonly delete_log=$(mktemp)

echo "## Workflow Cache Pruner" >> $GITHUB_STEP_SUMMARY
echo "" >> $GITHUB_STEP_SUMMARY
echo "**Repository:** \`$repository\` | **Branch:** \`$branch\`" >> $GITHUB_STEP_SUMMARY
echo "" >> $GITHUB_STEP_SUMMARY
echo "| Cache ID | Size | Branch | Age | Action |" >> $GITHUB_STEP_SUMMARY
echo "|----------|------|--------|-----|--------|" >> $GITHUB_STEP_SUMMARY

function acquire_cache_ids_and_process() {
  while IFS= read -r cache_entry_row; do
    read -r id size scale ref age age_scale passe <<< "$cache_entry_row"
    [[ -z "${id//}" ]] && continue

    if [[ "$age_scale" == "minutes" || "$age_scale" == "minute" ]]; then
      (( skipped++ ))
      echo "| $id | $size $scale | $ref | $age $age_scale | skipped (recent) |" >> $GITHUB_STEP_SUMMARY
    else
      if gh actions-cache delete "$id" --confirm 2>/dev/null; then
        (( deleted++ ))
        echo "deleted" >> "$delete_log"
        echo "| $id | $size $scale | $ref | $age $age_scale | deleted |" >> $GITHUB_STEP_SUMMARY
      else
        (( failed++ ))
        echo "| $id | $size $scale | $ref | $age $age_scale | **failed** |" >> $GITHUB_STEP_SUMMARY
      fi
    fi
  done < <(gh actions-cache list --order desc --limit 100)
}

acquire_cache_ids_and_process

# Summary
echo "" >> $GITHUB_STEP_SUMMARY
echo "**Deleted:** $deleted | **Skipped:** $skipped | **Failed:** $failed" >> $GITHUB_STEP_SUMMARY

echo "::notice title=Cache Pruning Complete::Deleted $deleted, skipped $skipped (recent), failed $failed"
rm -f "$delete_log"

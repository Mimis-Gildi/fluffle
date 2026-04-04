#!/usr/bin/env zsh
set -uo pipefail
declare -i MAX_PARALLEL=${MAX_PARALLEL:-100}

readonly repository="${REPO:-$(basename "$(git rev-parse --show-toplevel)")}"
readonly branch="${BRANCH:-$(git rev-parse --abbrev-ref HEAD)}"
echo "::notice title=Workflow Runs Pruner::Starting GH CLI pruning run for <$repository>"
echo "::notice title=Active Branch Detected::<$branch>"

declare -i KEEP_LAST=${KEEP_LAST:-2}
declare -i STALE_HOURS=${STALE_HOURS:-2}
declare -a workflows
declare -a runs_to_prune
declare -A queued_per_workflow
readonly delete_log=$(mktemp)

echo "## Workflow Runs Pruner" >> $GITHUB_STEP_SUMMARY
echo "" >> $GITHUB_STEP_SUMMARY
echo "**Repository:** \`$repository\` | **Branch:** \`$branch\` | **Keep last:** $KEEP_LAST" >> $GITHUB_STEP_SUMMARY
echo "" >> $GITHUB_STEP_SUMMARY

function acquire_workflows_to_process() {
  local -i workflow_count=0
  local -r debug="${1:-off}"

  echo "::group::Acquire workflows to inspect."
  local -r workflows_as_text="$(gh workflow list --json id,name,path,state -q '.[] | [ .id, .name, .path, .state ] | @csv')"
  while IFS= read -r workflow_row; do
    IFS=',' read -r workflow_id workflow_name workflow_path workflow_state <<< "${workflow_row//}"
    if [[ -z "${workflow_id// }" ]]; then
      echo "::error title=NOOP::Workflow $workflow_name has an empty ID that makes no sense. Skipping it!"
    else
      workflows+=("$workflow_id|$workflow_name|$workflow_path|$workflow_state")
      ((workflow_count++))
    fi
  done <<< "$workflows_as_text"
  echo "::notice title=Acquired Workflows::$workflow_count workflows to process."
  echo "::endgroup::"
}

function queue_run() {
  local run_id="$1" workflow_name="$2" reason="$3"
  runs_to_prune+=("$run_id|$workflow_name")
  queued_per_workflow[$workflow_name]=$(( ${queued_per_workflow[$workflow_name]:-0} + 1 ))
  echo "| $run_id | $workflow_name | $reason |" >> $GITHUB_STEP_SUMMARY
}

function prepare_workflows_to_process() {
  local -i runs_count=0 workflow_runs_count=0
  local -r debug="${1:-off}"
  local -i cutoff_epoch=$(( EPOCHSECONDS - STALE_HOURS * 3600 ))

  echo "::group::Prepare workflows to inspect."

  echo "### Queued for Deletion" >> $GITHUB_STEP_SUMMARY
  echo "" >> $GITHUB_STEP_SUMMARY
  echo "| Run ID | Workflow | Reason |" >> $GITHUB_STEP_SUMMARY
  echo "|--------|----------|--------|" >> $GITHUB_STEP_SUMMARY

  for workflow_row in "${workflows[@]}"; do
    IFS='|' read -r workflow_id workflow_name workflow_path workflow_state <<< "${workflow_row//\"/}"

    if [[ "$branch" != "main" ]]; then
      # Feature branch: prune this branch only, keep last KEEP_LAST
      if ! executed_runs_text="$(gh run list --workflow="$workflow_id" --branch="$branch" --json databaseId --limit 1000 | jq -r ".[$KEEP_LAST:][]?.databaseId")"; then
        echo "::error title=Run Query Failed::Could not query runs for workflow $workflow_name"
        continue
      fi
      while IFS= read -r run_id; do
        (( runs_count++ ))
        if [[ -n "${run_id//}" ]]; then
          queue_run "$run_id" "$workflow_name" "branch overflow"
          (( workflow_runs_count++ ))
        fi
      done <<< "${executed_runs_text}"
    else
      # Main: pass 1 -- main branch runs, keep last KEEP_LAST
      if ! executed_runs_text="$(gh run list --workflow="$workflow_id" --branch=main --json databaseId --limit 1000 | jq -r ".[$KEEP_LAST:][]?.databaseId")"; then
        echo "::error title=Run Query Failed::Could not query main runs for workflow $workflow_name"
        continue
      fi
      while IFS= read -r run_id; do
        (( runs_count++ ))
        if [[ -n "${run_id//}" ]]; then
          queue_run "$run_id" "$workflow_name" "main overflow"
          (( workflow_runs_count++ ))
        fi
      done <<< "${executed_runs_text}"

      # Main: pass 2 -- non-main branches, delete everything older than STALE_HOURS
      if ! executed_runs_json="$(gh run list --workflow="$workflow_id" --json databaseId,createdAt,headBranch --limit 1000)"; then
        echo "::error title=Run Query Failed::Could not query all runs for workflow $workflow_name"
        continue
      fi
      while IFS=$'\t' read -r run_id created_at head_branch; do
        (( runs_count++ ))
        [[ -z "${run_id//}" || "$head_branch" == "main" ]] && continue
        local -i run_epoch=$(date -d "$created_at" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$created_at" +%s 2>/dev/null || echo 0)
        if (( run_epoch > 0 && run_epoch < cutoff_epoch )); then
          queue_run "$run_id" "$workflow_name" "stale ($head_branch)"
          (( workflow_runs_count++ ))
        fi
      done < <(echo "$executed_runs_json" | jq -r '.[] | [.databaseId, .createdAt, .headBranch] | @tsv')
    fi
  done

  echo "" >> $GITHUB_STEP_SUMMARY
  echo "::notice title=Queued::$workflow_runs_count runs queued from $runs_count rows processed."
  echo "::endgroup::"
}

function process_workflows_to_process() {
  local -r debug="${1:-off}"
  local -i requests_count=0

  echo "::group::Processing deletion requests."
  echo "" >> $GITHUB_STEP_SUMMARY
  echo "### Deletion Results" >> $GITHUB_STEP_SUMMARY
  echo "" >> $GITHUB_STEP_SUMMARY

  for run_delete_request in "${runs_to_prune[@]}"; do
    IFS='|' read -r run_id run_workflow_name <<< "$run_delete_request"
    if [[ -n "${run_id// }" ]]; then
      (( requests_count++ ))
      (
        if gh run delete "$run_id"; then
          echo "$run_workflow_name" >> "$delete_log"
        else
          echo "::warning title=Delete Failed::Could not delete run $run_id of $run_workflow_name"
        fi
      ) &
      if (( requests_count % MAX_PARALLEL == 0 )); then
        wait
      fi
    fi
  done
  wait

  # Tally deletions from temp file (survives subshell forks)
  local summary_parts=()
  for wf_name in ${(k)queued_per_workflow}; do
    local -i deleted=$(grep -c "^${wf_name}$" "$delete_log" 2>/dev/null || echo 0)
    local queued=${queued_per_workflow[$wf_name]}
    summary_parts+=("$wf_name: $deleted/$queued")
    echo "- **$wf_name**: $deleted deleted of $queued queued" >> $GITHUB_STEP_SUMMARY
  done
  rm -f "$delete_log"

  local annotation_text="${(j:, :)summary_parts}"
  echo "::notice title=Pruning Complete::$requests_count total. ${annotation_text}"

  echo "" >> $GITHUB_STEP_SUMMARY
  echo "::endgroup::"
}

function main() {
  acquire_workflows_to_process "${1:-off}"
  prepare_workflows_to_process "${2:-on}"
  process_workflows_to_process "${3:-off}"
}

main "$@"

#!/usr/bin/env zsh
set -uo pipefail
declare -i MAX_PARALLEL=${MAX_PARALLEL:-100}

readonly repository="${REPO:-$(basename "$(git rev-parse --show-toplevel)")}"
readonly branch="${BRANCH:-$(git rev-parse --abbrev-ref HEAD)}"
echo "::notice title=Workflow Runs Pruner::Starting GH CLI pruning run for <$repository>"
echo "::notice title=Active Branch Detected::<$branch>"

declare -i KEEP_LAST=${KEEP_LAST:-2}
declare -a workflows
declare -a runs_to_prune
declare -A queued_per_workflow
declare -A deleted_per_workflow

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
    [[ "$debug" == "on" ]] && echo "::debug title=Reading a Workflow row::Workflow $workflow_name with ID $workflow_id in state $workflow_state and at path  $workflow_path."
    if [[ -z "${workflow_id// }" ]]; then
      echo "::notice title=NOOP::Workflow $workflow_name has an empty ID that makes no sense. Skipping it!"
    else
      workflows+=("$workflow_id|$workflow_name|$workflow_path|$workflow_state")
      ((workflow_count++))
    fi
  done <<< "$workflows_as_text"
  echo "::notice title=Acquired Workflows::$workflow_count workflows to process."
  echo "::endgroup::"
}

function prepare_workflows_to_process() {
  local -i runs_count=0 workflow_runs_count=0
  local -r debug="${1:-off}"

  echo "::group::Prepare workflows to inspect."

  echo "### Queued for Deletion" >> $GITHUB_STEP_SUMMARY
  echo "" >> $GITHUB_STEP_SUMMARY
  echo "| Run ID | Workflow |" >> $GITHUB_STEP_SUMMARY
  echo "|--------|----------|" >> $GITHUB_STEP_SUMMARY

  for workflow_row in "${workflows[@]}"; do
    IFS='|' read -r workflow_id workflow_name workflow_path workflow_state <<< "${workflow_row//\"/}"
    local branch_filter=""
    if [[ "$branch" != "main" ]]; then
      branch_filter="--branch=$branch"
    fi

    if ! executed_runs_text="$(gh run list --workflow="$workflow_id" $branch_filter --json databaseId --limit 1000 | jq -r ".[$KEEP_LAST:][]?.databaseId")"; then
      echo "::error title=Run Query Failed::Could not query runs for workflow $workflow_name"
      continue
    fi

    while IFS= read -r run_row; do
      (( runs_count++ ))
      if [[ -n "${run_row//}" ]]; then
        run_entry="$run_row|$workflow_name"
        runs_to_prune+=("$run_entry")
        (( workflow_runs_count++ ))
        queued_per_workflow[$workflow_name]=$(( ${queued_per_workflow[$workflow_name]:-0} + 1 ))
        echo "| $run_row | $workflow_name |" >> $GITHUB_STEP_SUMMARY
      fi
    done <<< "${executed_runs_text}"
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
          deleted_per_workflow[$run_workflow_name]=$(( ${deleted_per_workflow[$run_workflow_name]:-0} + 1 ))
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

  # Summary annotation: counts per workflow
  local summary_parts=()
  for wf_name in ${(k)queued_per_workflow}; do
    local deleted=${deleted_per_workflow[$wf_name]:-0}
    local queued=${queued_per_workflow[$wf_name]}
    summary_parts+=("$wf_name: $deleted/$queued")
    echo "- **$wf_name**: $deleted deleted of $queued queued" >> $GITHUB_STEP_SUMMARY
  done

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

#!/usr/bin/env zsh
set -uo pipefail

readonly testing="${test_run}"

readonly repo="${GITHUB_REPOSITORY}"
readonly event_name="${GITHUB_EVENT_NAME}"
readonly event_action="$(jq -r '.action' "$GITHUB_EVENT_PATH")"
readonly sender="$(jq -r '.sender.login' "$GITHUB_EVENT_PATH")"

readonly issue_number="$(jq -r '.issue.number // empty' "$GITHUB_EVENT_PATH")"
readonly pr_number="$(jq -r '.pull_request.number // empty' "$GITHUB_EVENT_PATH")"

readonly -i prior_issues_created_count=$(gh issue list --repo "$repo" --state all --author "$sender" --json id --jq 'length')
readonly -i prior_prs_raised_up_count=$(gh pr list --repo "$repo" --state all --author "$sender" --json id --jq 'length')

readonly issue_file="${MESSAGES_PATH}/issue-greeting.md"
readonly pr_file="${MESSAGES_PATH}/pr-greeting.md"

readonly greet_issues=$([[ -f "$issue_file" ]] && echo true || echo false)
readonly greet_prs=$([[ -f "$pr_file" ]] && echo true || echo false)

printf '::notice title=Welcome Action::%s %s %s by %s. Issue greeting %s, PR greeting %s.\n' \
  "$repo" "$event_name" "$event_action" "$sender" \
  "$([[ "$greet_issues" == "true" ]] && echo present || echo absent)" \
  "$([[ "$greet_prs" == "true" ]] && echo present || echo absent)"

# Discriminate once, then one linear flow
if [[ -n "$issue_number" ]]; then
  kind="issue" number="$issue_number" greeting="$greet_issues"
  file="$issue_file" prior=$prior_issues_created_count
elif [[ -n "$pr_number" ]]; then
  kind="PR" number="$pr_number" greeting="$greet_prs"
  file="$pr_file" prior=$prior_prs_raised_up_count
else
  printf '::error title=Inconsistent State::Neither issue nor PR number present on %s for %s, %s from %s.\n' \
    "$repo" "$event_name" "$event_action" "$sender"
  exit 111
fi

if [[ "$greeting" == "false" ]]; then
  printf '::warning title=No %s greeting::Create %s to greet first-time %s creators.\n' "$kind" "$file" "$kind"
  exit 0
fi

if [[ "$testing" != "true" ]] && (( prior > 1 )); then
  printf '::notice title=Oldtimer::%s has %i %ss raised.\n' "$sender" "$prior" "$kind"
  exit 0
fi

# First-time contributor -- post greeting
readonly message="$(cat "$file")"

case "$kind" in
  issue) gh issue comment "$number" --repo "$repo" --body "$message" ;;
  PR)    gh pr comment "$number" --repo "$repo" --body "$message" ;;
esac
printf '::notice title=Greeted::Posted %s greeting to %s on #%s.\n' "$kind" "$sender" "$number"

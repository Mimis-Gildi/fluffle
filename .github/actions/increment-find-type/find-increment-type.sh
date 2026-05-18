#!/usr/bin/env zsh

readonly LAST_MSG=$(git log -1 --format='%s')
readonly LAST_AUTHOR=$(git log -1 --format='%an')

printf 'Git state:\n\t author=%s\n\t message=%s\n\n' $LAST_AUTHOR $LAST_MSG

printf 'Tokens:\n\t GITHUB_TOKEN=%s\n\t GH_TOKEN=%s\n\n' \
  "$( [[ -n $GITHUB_TOKEN ]] && print 'Token is set' || print 'Token is NOT set' )" \
  "$( [[ -n $GH_TOKEN ]] && print 'Token is set' || print 'Token is NOT set' )"

[[ -n $GH_TOKEN ]] || {
  printf '::error title=Token::GH_TOKEN is empty. gh-token input did not resolve -- check secret wiring in the caller workflow.\n'
  exit 1
}

# Decompose PR_SKIP into its two drivers.
PR_OUT=$(gh pr view --json number --jq '.number' >&1) && IN_PR=1 || {
  [[ $PR_OUT == *'no pull requests found'* ]] && IN_PR=0 || {
    printf '::error title=PR Check::%s\n' $PR_OUT
    exit 1
  }
}
[[ $EVENT_NAME == push ]] && IN_PUSH=1 || IN_PUSH=0
(( IN_PR && IN_PUSH )) && PR_SKIP=1 || PR_SKIP=0

BRANCH=$(git branch --show-current >&1)
printf 'PR check:\n\t branch=%1$s\n\t head_ref=%2$s\n\t ref=%3$s\n\t gh_pr_view=%4$s\n\t IN_PR=%5$s\n\n' \
  $BRANCH ${HEAD_REF:- } $REF $PR_OUT $IN_PR

# Extract commit message signals.
[[ ${LAST_MSG:l}    == *'[push up]'*  ]] && MSG_MINOR=1 || MSG_MINOR=0
[[ ${LAST_MSG:l}    == *'[force up]'* ]] && MSG_MAJOR=1 || MSG_MAJOR=0
[[ ${LAST_MSG:l}    == *'[skip up]'*  ]] && MSG_SKIP=1  || MSG_SKIP=0
[[ ${LAST_AUTHOR:l} == *'[bot]'*      ]] && IS_BOT=1    || IS_BOT=0

# Trace all driving values.
printf '::notice title=Selector State::event=%1$s; action=%2$s; IN_PR=%3$s; IN_PUSH=%4$s; PR_SKIP=%5$s; MSG_MINOR=%6$s; MSG_MAJOR=%7$s; MSG_SKIP=%8$s; IS_BOT=%9$s; force_major=%10$s; force_minor=%11$s; author=%12$s; msg=%13$s\n' \
  $EVENT_NAME ${EVENT_ACTION:- } $IN_PR $IN_PUSH $PR_SKIP $MSG_MINOR $MSG_MAJOR $MSG_SKIP $IS_BOT $FORCE_MAJOR $FORCE_MINOR $LAST_AUTHOR $LAST_MSG

# Boundary check: trigger filters exclude renovate/** and dependabot/**, so a bot-triggered create reaching us means the filter is broken upstream.
[[ $EVENT_NAME == create && $ACTOR == *'[bot]'* ]] && {
  printf '::error title=Trigger Filter::Bot %s triggered create -- should be excluded by branches filter. Fix the filter, not the selector.\n' \
  $ACTOR
  exit 1
}

# Determine increment type -- order = priority, low first, terminal rules last.
TYPE=patch
[[ $EVENT_NAME == pull_request || $FORCE_MINOR == true || ${LAST_MSG:l} == *'[push up]'*  ]] && TYPE=minor
{ (( PR_SKIP )) || [[ ${LAST_MSG:l} == *'[skip up]'* || ${LAST_AUTHOR:l} == *'[bot]'* ]]; } && TYPE=skip
[[ $EVENT_NAME == create       || $FORCE_MAJOR == true || ${LAST_MSG:l} == *'[force up]'* ]] && TYPE=major

printf '::notice title=Increment Type::%s\n' $TYPE
print -- "type=$TYPE" > $GITHUB_OUTPUT

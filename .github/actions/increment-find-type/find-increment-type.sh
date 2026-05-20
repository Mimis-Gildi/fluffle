#!/usr/bin/env zsh

readonly ACTIONS=(fail skip patch minor major)
readonly DEFAULT_ACTION=$ACTIONS[2]
readonly DEFAULT_INC=$ACTIONS[3]

printf "type=%s\n" $DEFAULT_ACTION > $GITHUB_OUTPUT

readonly LAST_MSG=$(git log -1 --format='%s')
readonly LAST_AUTHOR=$(git log -1 --format='%an')
readonly BRANCH=$(git branch --show-current)

printf 'Action State on Invocation:

      GITHUB_TOKEN : %s \t# Agent supplied fallback
          GH_TOKEN : %s \t# Workflow supplied value
            BRANCH : %s \t# Calculated branch
      Last Message : %s
       Last Author : %s
             ACTOR : %s
        EVENT_NAME : %s
      EVENT_ACTION : %s
               REF : %s \t# Action source pointer
          HEAD_REF : %s \t# Pull request source branch

       FORCE_ACTION : %s
\n\n' \
  "$( [[ -n $GITHUB_TOKEN ]] && print 'Token is set' || print 'Token is NOT set' )" \
  "$( [[ -n $GH_TOKEN ]] && print 'Token is set' || print 'Token is NOT set' )" \
  $BRANCH \
  $LAST_MSG $LAST_AUTHOR $ACTOR \
  $EVENT_NAME ${EVENT_ACTION:-Not provisioned} \
  $REF ${HEAD_REF:-Not provisioned} ${FORCE_ACTION:-none}

[[ $EVENT_NAME == workflow_dispatch ]] && {
  case $FORCE_ACTION in
    major)
      printf '::notice title=Major-Selected::event=%s, action=%s, message=%s, author=%s (actor=%s).\n' \
        $EVENT_NAME $FORCE_ACTION $LAST_MSG $LAST_AUTHOR $ACTOR
      print "type=$ACTIONS[5]" > $GITHUB_OUTPUT
      exit 0
      ;;
    minor)
      printf '::notice title=Minor-Selected::event=%s, action=%s, message=%s, author=%s (actor=%s).\n' \
        $EVENT_NAME $FORCE_ACTION $LAST_MSG $LAST_AUTHOR $ACTOR
      print "type=$ACTIONS[4]" > $GITHUB_OUTPUT
      exit 0
      ;;
    patch)
      printf '::notice title=Patch-Selected::event=%s, action=%s, message=%s, author=%s (actor=%s).\n' \
        $EVENT_NAME $FORCE_ACTION $LAST_MSG $LAST_AUTHOR $ACTOR
      print "type=$DEFAULT_INC" > $GITHUB_OUTPUT
      exit 0
      ;;
    skip)
      printf '::notice title=SKIP-Selected::event=%s, action=%s, message=%s, author=%s (actor=%s).\n' \
        $EVENT_NAME $FORCE_ACTION $LAST_MSG $LAST_AUTHOR $ACTOR
      print "type=$DEFAULT_ACTION" > $GITHUB_OUTPUT
      exit 0
      ;;
    fail)
      printf '::notice title=FAIL-Selected::event=%s, action=%s, message=%s, author=%s (actor=%s).\n' \
        $EVENT_NAME $FORCE_ACTION $LAST_MSG $LAST_AUTHOR $ACTOR
      print "type=$ACTIONS[1]" > $GITHUB_OUTPUT
      exit 1
      ;;
    *)
      printf '::error title=Impossible FAIL::Invalid action selection!
      event=%s, action=%s, message=%s, author=%s (actor=%s).\n' \
        $EVENT_NAME $FORCE_ACTION $LAST_MSG $LAST_AUTHOR $ACTOR
      print "type=$ACTIONS[1]" > $GITHUB_OUTPUT
      exit 1
      ;;
  esac
}

[[ $EVENT_NAME == create ]] && {
    print "type=$ACTIONS[5]" > $GITHUB_OUTPUT
    printf '::notice title=Major-Create::event=%s, force_major=%s, last_message=%s, last_author=%s (actor=%s).\n' \
    $EVENT_NAME ${FORCE_ACTION:-none} $LAST_MSG $LAST_AUTHOR $ACTOR
    exit 0
}

[[ ${LAST_AUTHOR:l} == *'[bot]'* ]] && {
  printf '::error title=Bot-Ignored::Ignoring all bot operations.
  With event=%s, force_major=%s, last_message=%s, last_author=%s (actor=%s).\n' \
  $EVENT_NAME ${FORCE_ACTION:-none} $LAST_MSG $LAST_AUTHOR $ACTOR
  exit 0
}

[[ ${LAST_MSG:l} == *'[skip up]'* ]] && {
  print '::warning title=SKIP::User requested skip acknowledged.'
  exit 0
}

[[ $EVENT_NAME == push ]] && {
  OPEN_PR_EXISTS=$(gh pr list --head ${REF#refs/heads/} --state open --json number --jq 'any') || {
    print '::error title=PR Check Failed::Crashing workflow because the check for open PRs failed.'
    print "type=$ACTIONS[1]" > $GITHUB_OUTPUT
    exit 1
  }
  [[ $OPEN_PR_EXISTS == true ]] && {
    print '::notice title=Yielding to PR Synchronize::Open PRs exist and incrementing is yielding to PR events and not Push events.'
    exit 0
  }

  case ${LAST_MSG:l} in
    *'[force up]'*)
      printf '::notice title=Minor-Forced-Push::Major increment on push is forbidden: event=%s, action=%s, message=%s, author=%s (actor=%s).\n' \
        $EVENT_NAME ${FORCE_ACTION:-none} $LAST_MSG $LAST_AUTHOR $ACTOR
      print "type=$ACTIONS[4]" > $GITHUB_OUTPUT
      exit 0
      ;;
    *'[push up]'*)
      printf '::notice title=Minor-Push::event=%s, action=%s, message=%s, author=%s (actor=%s).\n' \
        $EVENT_NAME ${FORCE_ACTION:-none} $LAST_MSG $LAST_AUTHOR $ACTOR
      print "type=$ACTIONS[4]" > $GITHUB_OUTPUT
      exit 0
      ;;
    *)
      printf '::notice title=Patch-Default::event=%s, action=%s, message=%s, author=%s (actor=%s).\n' \
        $EVENT_NAME ${FORCE_ACTION:-none} $LAST_MSG $LAST_AUTHOR $ACTOR
      print "type=$DEFAULT_INC" > $GITHUB_OUTPUT
      exit 0
      ;;
  esac
}

case ${LAST_MSG:l} in
  *'[force up]'*)
    printf '::notice title=Forced-Major::event=%s, action=%s, message=%s, author=%s (actor=%s).\n' \
      $EVENT_NAME ${FORCE_ACTION:-none} $LAST_MSG $LAST_AUTHOR $ACTOR
    print "type=$ACTIONS[5]" > $GITHUB_OUTPUT
    exit 0
    ;;
  *)
    printf '::notice title=Minor-Default::event=%s, action=%s, message=%s, author=%s (actor=%s).\n' \
      $EVENT_NAME ${FORCE_ACTION:-none} $LAST_MSG $LAST_AUTHOR $ACTOR
    print "type=$ACTIONS[4]" > $GITHUB_OUTPUT
    exit 0
    ;;
esac

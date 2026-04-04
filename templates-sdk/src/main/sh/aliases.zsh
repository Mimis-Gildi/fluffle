#!/usr/bin/env zsh
### Aliases

## Agent Root
alias up="apt update && apt -y dist-upgrade && apt -y autoremove && apt -y autoclean"
alias upX="apt update && apt -y dist-upgrade && apt -y autoremove && apt -y autoclean && rm -rf /var/lib/apt/lists/*"

alias du-all="du -sh * .[^.]*"
alias du-hid="du -sh .[^.]*"
alias du-dir="du -sh *"



## Local
alias tom="ssh -Y lugaru@tom"
alias toad="ssh -Y lugaru@toad"
alias kirby="ssh -Y lugaru@kirby"
alias jerry="ssh -Y lugaru@jerry"
alias cpt-L="ssh -Y captainl@captain-ws"

alias gfp='git fetch --prune && git branch -r | awk "{print \$1}" | egrep -v -f /dev/fd/0 <(git branch -vv | grep origin) | awk "{print \$1}"'
alias gfpd='git fetch --prune && git branch -r | awk "{print \$1}" | egrep -v -f /dev/fd/0 <(git branch -vv | grep origin) | awk "{print \$1}" | xargs git branch -d'
alias gfpX='git fetch --prune && git branch -r | awk "{print \$1}" | egrep -v -f /dev/fd/0 <(git branch -vv | grep origin) | awk "{print \$1}" | xargs git branch -D'

alias site='bundle exec jekyll serve -wolIt'


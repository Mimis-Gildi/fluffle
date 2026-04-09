# Team's share inbox

_We hold our thoughts and stickies here..._

- \[skip up\] - same as \[skip ci\], drops any incrementing regardless of else.
- \[push up\] - encourages a minor version upgrade which trumps a patch.
- \[force up\] - encourages a major version bump.

\[force up]\ trumps \[push up\].
And \[skip up/ci\] trumps everything.



---

## Sloppy ideas about detachments

```zsh
  BRANCH="${GITHUB_HEAD_REF:-$(git rev-parse --abbrev-ref HEAD)}"                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     
  git fetch origin "$BRANCH"                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          
  git checkout "$BRANCH"
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      
  # Fail if local has commits that remote doesn't -- that's unexpected in CI                                                                                                                                                                                                                                                                                                                                                                                                                                                                          
  LOCAL=$(git rev-parse HEAD)
  REMOTE=$(git rev-parse "origin/$BRANCH")                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            
  if [[ "$LOCAL" != "$REMOTE" ]]; then                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              
    echo "::error title=Unexpected State::Local HEAD ($LOCAL) != origin/$BRANCH ($REMOTE). Aborting."                                                                                                                                                                                                                                                                                                                                                                                                                                                 
    exit 1                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            
  fi                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  
       
```
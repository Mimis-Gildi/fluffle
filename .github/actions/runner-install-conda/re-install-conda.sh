#!/usr/bin/env zsh

readonly summary=$(<<'EOF'
## Conda Install

Outcome: %s

### Conda `info`

```text
%s
```

### Mamba `info`

```text
%s
```

## Python base %s

```text
%s
```


## Python ml %s

```text
%s
```

## Packages ml %s

```text
%s
```

EOF
)

print 'completed=false' > $GITHUB_OUTPUT

#ToDo:
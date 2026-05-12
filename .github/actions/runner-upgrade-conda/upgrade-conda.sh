#!/usr/bin/env zsh

readonly summary=$(<<'EOF'
## Conda Upgrade

Running %s

### Conda `info`

```text
%s
```

### Mamba `info`

```text
%s
```

EOF
)

print 'upgraded=false' > $GITHUB_OUTPUT

readonly activation=${0:A:h}/conda-activate.sh
[[ -s $activation ]] && source $activation

conda upgrade -y python
conda upgrade -y conda
conda upgrade -y mamba
conda upgrade -y --all
conda clean -y -a

conda activate ml
conda upgrade -y python
conda upgrade -y --all
conda clean -y -a

print 'upgraded=true' > $GITHUB_OUTPUT

printf $summary \
"$(python --version)" \
"$(conda info)" \
"$(mamba info)" > $GITHUB_STEP_SUMMARY
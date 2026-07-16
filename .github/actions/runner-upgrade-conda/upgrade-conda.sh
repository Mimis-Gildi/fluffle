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

## Package updates since %s

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
conda config --append channels conda-pypi

conda upgrade -y python
conda install -y conda-pypi pydantic pyfunctional \
diagrams pyyaml pytest requests fastapi jproperties  \
numpy pandas scikit-learn matplotlib seaborn pytorch \
xgboost lightgbm shap imbalanced-learn optuna plotly tabulate
conda upgrade -y --all
conda clean -y -a

readonly since=$(date -d '-1 hour' '+%F %T')
readonly changes=$(conda list --revisions | awk -v RS='' -v since="$since" 'substr($0, 1, 19) >= since { print $0 "\n" }')

print 'upgraded=true' > $GITHUB_OUTPUT

printf $summary \
"$(python --version)" \
"$(conda info)" \
"$(mamba info)" \
$since \
$changes > $GITHUB_STEP_SUMMARY

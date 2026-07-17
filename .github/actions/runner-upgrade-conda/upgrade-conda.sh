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

print "\n ============ BASE environment.   ============\n"
conda upgrade -y python
conda upgrade -y conda
conda upgrade -y mamba
conda upgrade -y --all
conda clean -y -a

print "\n ============ ML environment.     ============\n"
conda activate ml || exit 11

print "\n Upgrade Python first to rebalance dependency tree."
conda upgrade -y python

print "\n Force dependencies: conda pypi."
conda config --append channels conda-pypi
conda install -y conda-pypi

print "\n Force general dependencies: pydantic pyfunctional pyyaml pytest requests fastapi jproperties."
conda install -y pydantic pyfunctional pyyaml pytest requests fastapi jproperties

print "\n Force data science dependencies: numpy pandas scikit-learn pytorch xgboost lightgbm shap imbalanced-learn optuna."
conda install -y numpy pandas scikit-learn pytorch xgboost lightgbm shap imbalanced-learn optuna

print "\n Force Keras superstructure: keras."
conda env config vars set KERAS_BACKEND=torch -n ml
conda install -y keras

print "\n Add graphing and presentation utilities: diagrams matplotlib seaborn plotly tabulate."
conda install -y diagrams matplotlib seaborn plotly tabulate

print "\n Upgrade proof-pass."
conda upgrade -y --all

print "\n Mandatory cleanout."
conda clean -y -a

readonly since=$(date -d '-1 hour' '+%F %T')
readonly changes=$(conda list --revisions | awk -v RS='' -v since="$since" 'substr($0, 1, 19) >= since { print $0 "\n" }')

print 'upgraded=true' > $GITHUB_OUTPUT

printf $summary \
"$(python --version)" \
"$(conda info)" \
"$(mamba info)" \
"$since" \
"$changes" > $GITHUB_STEP_SUMMARY

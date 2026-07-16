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
conda config --append channels conda-pypi

conda upgrade -y python
conda install -y conda-pypi pydantic pyfunctional \
diagrams pyyaml pytest requests fastapi jproperties  \
numpy pandas scikit-learn matplotlib seaborn pytorch \
xgboost lightgbm shap imbalanced-learn optuna plotly tabulate
conda upgrade -y --all
conda clean -y -a

print 'upgraded=true' > $GITHUB_OUTPUT

printf $summary \
"$(python --version)" \
"$(conda info)" \
"$(mamba info)" > $GITHUB_STEP_SUMMARY

#   Include — utility layer (used by scripts across repos, tiny installs):
  #  - pyfunctional — top .py import (13), conda-forge only
  #  - pyyaml, pytest, requests — recurring in scripts, standard CI needs
  #
  #  Include — data core (recurring in both scripts and notebooks):
  #  - numpy, pandas, scikit-learn, matplotlib, seaborn — the backbone; sklearn alone had 100 imports
  #  - jupyter — if the runner ever executes notebooks (nbconvert/CI); if notebooks stay laptop-only, drop it
  #
  #  Include if the runner is doing real ML duty — modest-size boosters:
  #  - xgboost, lightgbm, shap, imbalanced-learn, optuna, plotly, tabulate — each appeared 1–2×, but they cluster in the same notebooks that run sklearn
  #
  #  Deliberately excluded, with reasons:
  #  - tensorflow/keras, pytorch/torchvision — gigabyte-scale, slow solves, GPU-variant decisions; that's a per-project or dedicated-env commitment, not a canary default
  #  - boto3, google-api-python-client, fastapi, pydantic, jproperties — each traced to one project; project envs own them
  #  - pygame, diagrams — single-project; diagrams also drags in system graphviz

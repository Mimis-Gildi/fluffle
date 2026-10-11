#!/usr/bin/env zsh

conda_ml(){
  conda create -y -n $1 -c conda-forge python=$2 \
    lightgbm xgboost catboost imbalanced-learn seaborn matplotlib \
    shap optuna kagglehub notebook itables jproperties hatch diagrams \
    black argcomplete bottleneck pytest pyfunctional fastapi scikit-learn
}
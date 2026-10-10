#!/usr/bin/env zsh

conda_ml(){
  conda create -y -n ml -c conda-forge python=3.12 \
    lightgbm xgboost catboost imbalanced-learn seaborn matplotlib \
    shap optuna kagglehub notebook itables jproperties hatch diagrams \
    black argcomplete bottleneck pytest pyfunctional fastapi scikit-learn
}
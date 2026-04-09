#!/usr/bin/env zsh

echo -e "## Conda Upgrade\n" >> $GITHUB_STEP_SUMMARY
echo "upgraded=false" > "$GITHUB_OUTPUT"

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$("${HOME}/miniforge3/bin/conda" 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "${HOME}/miniforge3/etc/profile.d/conda.sh" ]; then
        . "${HOME}/miniforge3/etc/profile.d/conda.sh"
    else
        export PATH="${HOME}/miniforge3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

# >>> mamba initialize >>>
# !! Contents within this block are managed by 'mamba shell init' !!
export MAMBA_EXE="${HOME}/miniforge3/bin/mamba";
export MAMBA_ROOT_PREFIX="${HOME}/miniforge3";
__mamba_setup="$("$MAMBA_EXE" shell hook --shell zsh --root-prefix "$MAMBA_ROOT_PREFIX" 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__mamba_setup"
else
    alias mamba="$MAMBA_EXE"  # Fallback on help from mamba activate
fi
unset __mamba_setup
# <<< mamba initialize <<<

conda upgrade -y python
conda upgrade -y conda
conda upgrade -y mamba
conda upgrade -y --all
conda clean -y -a

conda activate ml
conda upgrade -y python
conda upgrade -y --all
conda clean -y -a

python --version 2>/dev/null >> $GITHUB_STEP_SUMMARY
conda info 2>/dev/null >> $GITHUB_STEP_SUMMARY
mamba info 2>/dev/null >> $GITHUB_STEP_SUMMARY

echo "upgraded=true" > "$GITHUB_OUTPUT"

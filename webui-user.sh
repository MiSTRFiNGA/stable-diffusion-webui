#!/bin/bash
#########################################################
# Uncomment and change the variables below to your need:#
#########################################################

# Install directory without trailing slash
#install_dir="/home/$(whoami)"

# Name of the subdirectory
#clone_dir="stable-diffusion-webui"

# Commandline arguments for webui.py, for example: export COMMANDLINE_ARGS="--medvram --opt-split-attention"
#export COMMANDLINE_ARGS=""

# python3 executable
#python_cmd="python3"

# git executable
#export GIT="git"

# python3 venv without trailing slash (defaults to ${install_dir}/${clone_dir}/venv)
#venv_dir="venv"

# script to launch to start the app
#export LAUNCH_SCRIPT="launch.py"

# install command for torch
#export TORCH_COMMAND="pip install torch==1.12.1+cu113 --extra-index-url https://download.pytorch.org/whl/cu113"

# Requirements file to use for stable-diffusion-webui
#export REQS_FILE="requirements_versions.txt"

# Fixed git repos
#export K_DIFFUSION_PACKAGE=""
#export GFPGAN_PACKAGE=""

# Fixed git commits
#export STABLE_DIFFUSION_COMMIT_HASH=""
#export TAMING_TRANSFORMERS_COMMIT_HASH=""
#export CODEFORMER_COMMIT_HASH=""
#export BLIP_COMMIT_HASH=""

# Uncomment to enable accelerated launch
#export ACCELERATE="True"

###########################################

# ── JARVIS II Thin Client — Controller Mode ──────────────────────────────────
# Uncomment the block below when running as a headless Android controller.
# Set HIVEMIND_IP to your HiVEMiND Tailscale address before starting.
#
# export JARVIS_MODE=CONTROLLER
# export HIVEMIND_IP=100.x.x.x
#
# When MODE=CONTROLLER the webui is launched API-only (no GPU, no model load).
# All generation requests are proxied to HiVEMiND by jarvis_mobile/jarvis_controller.py.
# To activate controller mode, uncomment and run via:
#   bash jarvis_mobile/start_brain.sh
# ─────────────────────────────────────────────────────────────────────────────

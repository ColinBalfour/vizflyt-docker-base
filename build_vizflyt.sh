#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-/VizFlyt}"

echo "==> Target directory: ${TARGET_DIR}"
mkdir -p "${TARGET_DIR}"
cd "${TARGET_DIR}"

# Clone repo only if it doesn't exist (works with host-mounted /VizFlyt)
if [ ! -d "${TARGET_DIR}/.git" ] && [ ! -d "${TARGET_DIR}/VizFlyt/.git" ]; then
  echo "==> Cloning VizFlyt"
  git clone https://github.com/High-Speed-Drone-MQP/VizFlyt.git
fi

# Enter repo root (supports both: cloned as ./VizFlyt or already at /VizFlyt)
if [ -d "${TARGET_DIR}/VizFlyt" ]; then
  cd VizFlyt
fi

# --- Python 3.10 venv ---
if [ ! -d ".vizflyt" ]; then
  echo "==> Creating Python venv (.vizflyt)"
  python3 -m venv .vizflyt
fi

# Activate
# shellcheck disable=SC1091
source .vizflyt/bin/activate

# Upgrade pip
python3 -m pip install --upgrade pip

# PyTorch (CUDA 11.8)
pip install torch==2.1.2+cu118 torchvision==0.16.2+cu118 \
  --extra-index-url https://download.pytorch.org/whl/cu118

# Numpy < 2
pip install --upgrade "numpy<2"

# tiny-cuda-nn (optimized CUDA ops)
pip install wheel ninja
pip install git+https://github.com/NVlabs/tiny-cuda-nn/#subdirectory=bindings/torch

# Nerfstudio (editable)
cd nerfstudio
pip install --upgrade pip setuptools
pip install -e .
cd ..

# Extra Python deps
pip install transforms3d gdown pyquaternion

# Configure setup.cfg with your helper (provided by the repo)
# shellcheck disable=SC1091
source setup_cfg.sh

# Build ROS 2 workspace
cd vizflyt_ws/
colcon build

echo "==> build_vizflyt.sh complete."

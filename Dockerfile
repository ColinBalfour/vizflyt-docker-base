# ---------- Config ----------
ARG CUDA_VERSION=11.8.0
ARG CUDNN_VERSION=cudnn8
ARG ROS_DISTRO=humble
ARG USERNAME=dev
ARG UID=1000
ARG GID=1000
# ----------------------------

FROM nvidia/cuda:${CUDA_VERSION}-${CUDNN_VERSION}-devel-ubuntu22.04
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
ARG ROS_DISTRO
ARG USERNAME UID GID

# --- Base OS + dev tools (root) ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    locales curl gnupg2 lsb-release ca-certificates apt-transport-https \
    build-essential cmake ninja-build pkg-config git git-lfs \
    python3 python3-pip python3-venv python3-dev \
    ffmpeg libgl1 libglib2.0-0 \
    sudo vim nano htop tmux \
 && rm -rf /var/lib/apt/lists/*

# Locale
RUN locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# --- ROS 2 apt repo + key (root) ---
RUN mkdir -p /etc/apt/keyrings && \
    curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
      | gpg --dearmor -o /etc/apt/keyrings/ros-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/ros-archive-keyring.gpg] \
      http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" \
      > /etc/apt/sources.list.d/ros2.list

# --- ROS 2 + tools (root) ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-${ROS_DISTRO}-desktop \
    python3-colcon-common-extensions \
    python3-rosdep python3-rosinstall python3-vcstool \
    cmake \
&& rm -rf /var/lib/apt/lists/*
RUN rosdep init || true && rosdep update

# --- Vicon SDK libs from ros2-vicon-receiver (root) ---
RUN git clone --depth=1 https://github.com/OPT4SMART/ros2-vicon-receiver /tmp/ros2-vicon-receiver && \
    bash /tmp/ros2-vicon-receiver/install_libs.sh && \
    rm -rf /tmp/ros2-vicon-receiver

# --- CUDA envs (root) ---
ENV CUDA_HOME=/usr/local/cuda
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}

# --- Global venv + Python deps (root) ---
ENV VIZFLYT_VENV=/opt/vizflyt/.vizflyt
RUN mkdir -p /opt/vizflyt && \
    python3 -m venv ${VIZFLYT_VENV} && \
    source ${VIZFLYT_VENV}/bin/activate && \
    python -m pip install --upgrade pip wheel setuptools && \
    # PyTorch cu118 + torchvision
    pip install --no-cache-dir \
      torch==2.1.2+cu118 torchvision==0.16.2+cu118 \
      --extra-index-url https://download.pytorch.org/whl/cu118 && \
    # Keep numpy <2
    pip install --no-cache-dir "numpy<2" && \
    # tiny-cuda-nn (builds against CUDA toolkit)
    pip install --no-cache-dir ninja && \
    # Nerfstudio from PyPI (editable can be done at runtime if desired)
    pip install --no-cache-dir nerfstudio && \
    # Packages for ROS build
    pip install --no-cache-dir "empy<4.0" catkin_pkg lark && \
    # Extra deps
    pip install --no-cache-dir transforms3d gdown pyquaternion

# Make sure dev user can read/write the venv dir if needed
RUN chown -R ${UID}:${GID} /opt/vizflyt

# --- Create non-root user (last root step before switching) ---
RUN groupadd -g ${GID} ${USERNAME} && \
    useradd -m -s /bin/bash -u ${UID} -g ${GID} ${USERNAME} && \
    usermod -aG sudo ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Auto-source ROS in interactive shells
RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> ~/.bashrc

# Standard mount point for your live code
ENV VIZFLYT_DIR=/VizFlyt
RUN mkdir -p ${VIZFLYT_DIR}

# --- Copy helper scripts from build context (same folder as Dockerfile) ---
COPY --chown=${USERNAME}:${USERNAME} vizflyt-shell /usr/local/bin/vizflyt-shell
COPY --chown=${USERNAME}:${USERNAME} vizflyt-setup /usr/local/bin/vizflyt-setup
RUN chmod +x /usr/local/bin/vizflyt-shell /usr/local/bin/vizflyt-setup

# --- Drop to non-root user ---
USER ${USERNAME}
WORKDIR /home/${USERNAME}

# Default entry: ROS + global venv (and sources /VizFlyt overlay if it exists)
ENTRYPOINT ["vizflyt-shell"]
CMD ["/bin/bash"]

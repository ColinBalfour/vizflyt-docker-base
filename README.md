# VizFlyt ROS 2 + CUDA Dev Container

A GPU-enabled ROS 2 Humble development image for the VizFlyt project.  
It ships CUDA 11.8 (devel), a global Python venv with ML/NeRF deps, helper scripts, and the binary libs required by `ros2-vicon-receiver`.

---

## What’s inside

- **Base:** `nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04`
- **ROS 2:** Humble (`ros-humble-desktop`) + `colcon`, `rosdep`, `vcstool`
- **Global venv:** `/opt/vizflyt/.vizflyt` with:
  - `torch==2.1.2+cu118`, `torchvision==0.16.2+cu118`
  - `numpy<2`, `nerfstudio`, `transforms3d`, `gdown`, `pyquaternion`
  - ROS build helpers: `"empy<4.0"`, `catkin_pkg`, `lark`
- **Vicon DataStream SDK** (installed via `ros2-vicon-receiver/install_libs.sh`)
- **Helper scripts inside the image**
  - `vizflyt-shell` — entrypoint; activates venv **before** sourcing ROS; sources your overlay if present
  - `vizflyt-setup` — one-shot project setup (runtime build of tiny-cuda-nn, optional editable Nerfstudio, writes `setup.cfg`, runs `colcon build`)
- **User:** non-root `dev` (passwordless sudo)
- **Mount point for your code:** `/VizFlyt`

---

## Requirements

- NVIDIA driver on host + **nvidia-container-toolkit**
- Docker 20.10+
- Your repo directory on host: `~/VizFlyt` (or adjust the mount path)

---

### Installing Vizflyt
If vizflyt is not already downloaded, use the following commands:
```bash
git clone https://github.com/pearwpi/VizFlyt
cd VizFlyt/vizflyt_ws/src
./download_data_and_outputs.sh 
```

## Build the image

From the folder containing the **Dockerfile** (and the two helper scripts `vizflyt-shell`, `vizflyt-setup`):

```bash
docker build -t vizflyt:humble-cu118 .
```

> Optional build args:
> ```bash
> --build-arg CUDA_VERSION=11.8.0 > --build-arg ROS_DISTRO=humble > --build-arg USERNAME=dev --build-arg UID=$(id -u) --build-arg GID=$(id -g)
> ```

---

## Run the container (with your repo mounted)

### Linux / WSL2
```bash
xhost +local:root  # (optional) if using X11 GUIs
docker run -it --rm --gpus all --network host --ipc host   -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix:rw   -v $HOME/VizFlyt:/VizFlyt   --name vizflyt   vizflyt:humble-cu118
```

### macOS (Docker Desktop)
```bash
docker run -it --rm --gpus all   -v $HOME/VizFlyt:/VizFlyt   --name vizflyt   vizflyt:humble-cu118
```

On start you should see the entrypoint log which Python is active; it should be:
```
/opt/vizflyt/.vizflyt/bin/python
```

---

## One-time project setup inside the container

Run this after your repo is mounted at `/VizFlyt`:

```bash
vizflyt-setup /VizFlyt
```

- Builds **tiny-cuda-nn** at runtime (GPU required).
- Writes `setup.cfg` for `vizflyt` with `executable = /opt/vizflyt/.vizflyt/bin/python`.
- Runs **`colcon build`** (default: **no** `--symlink-install`).

If you’re hacking on **Nerfstudio** from your working tree:
```bash
vizflyt-setup /VizFlyt --editable-nerfstudio
```

---

## Everyday development

```bash
# (in container)
source /VizFlyt/vizflyt_ws/install/setup.bash   # if not auto-sourced yet
colcon build                                    # rebuild after code changes (no --symlink-install)
```

Open a **second shell** into the same running container:
```bash
~$ docker exec -it vizflyt bash
~$ source vizflyt-shell
```

---

## Ensuring ROS uses the venv Python

- The entrypoint activates the venv **before** sourcing ROS.
- `vizflyt-setup` writes:
  ```
  /VizFlyt/vizflyt_ws/src/vizflyt/setup.cfg
  [build_scripts]
  executable = /opt/vizflyt/.vizflyt/bin/python
  ```
- For **CMake** packages, pass Python explicitly if needed:
  ```bash
  colcon build     --cmake-args -DPYTHON_EXECUTABLE=/opt/vizflyt/.vizflyt/bin/python -DPython3_EXECUTABLE=/opt/vizflyt/.vizflyt/bin/python
  ```

---

## Image layout

```
/opt/vizflyt/.vizflyt/       # global Python venv (PyTorch cu118, nerfstudio, etc.)
/usr/local/bin/vizflyt-shell # entrypoint; activates venv, sources ROS, overlays
/usr/local/bin/vizflyt-setup # one-shot setup helper (tcnn build, setup.cfg, colcon)
/VizFlyt                     # your mounted project root (host bind mount)
```

---

## Troubleshooting

- **Container exits immediately**
  - Don’t override `--entrypoint` unless needed. The image uses `/usr/local/bin/vizflyt-shell` as PID 1.
- **Venv not active**
  - In container: `which python && python -c 'import sys; print(sys.executable)'`  
    Should show `/opt/vizflyt/.vizflyt/bin/python`.
- **GPU not visible / tiny-cuda-nn build skipped**
  - Start with `--gpus all`.  
  - Check: `python -c "import torch; print(torch.cuda.is_available())"`.
  - Force a specific SM arch for tiny-cuda-nn if necessary:
    ```bash
    vizflyt-setup /VizFlyt --tcnn-arch=86
    ```
- **X11 GUI doesn’t display**
  - Linux: `xhost +local:root` and mount `/tmp/.X11-unix`.  
  - macOS/Windows: consider GUI tools like Foxglove or VNC.

---

## Why this design?

- **Reproducible**: heavy deps baked at build time (CUDA/ROS + venv with pinned packages).
- **Fast iteration**: your code stays on the host (`/VizFlyt`), not inside the image.
- **Pragmatic**: GPU-specific builds (tiny-cuda-nn) happen at runtime against the actual device.

---

## Quick reference

- Build image:  
  `docker build -t vizflyt:humble-cu118 .`
- Run with mount + GPU:  
  `docker run -it --rm --gpus all -v $HOME/VizFlyt:/VizFlyt --name vizflyt vizflyt:humble-cu118`
- One-time setup:  
  `vizflyt-setup /VizFlyt`
- Second shell:  
  `docker exec -it vizflyt bash`

# Common ROS 2 Jazzy Development Image

English | [中文](README_zh.md)

Based on `osrf/ros:jazzy-desktop-full` (Ubuntu 24.04), with colcon, rosdep, GDB,
clangd, RViz 2, rqt, PlotJuggler, Nav2, SLAM Toolbox, MoveIt, Gazebo integration,
and ros2_control. Also includes Node.js 24 (with npm) and MuJoCo 3.15.0 (physics engine, Python bindings, and viewer).

## Host Requirements and Distribution Differences

Use **x86_64 (amd64) Linux + Docker Engine as a system service + the Compose plugin**.
The base image targets `linux/amd64`; see [OSRF image details](https://github.com/osrf/docker_images#osrf-profile).

| Host | Instructions |
|------|--------------|
| Ubuntu 22.04/24.04/26.04 | Follow the complete walkthrough below |
| Debian 12/13 | Replace the installation part of step 1 with [Docker's Debian instructions](https://docs.docker.com/engine/install/debian/), using the Debian repository; use the Toolkit `apt` instructions |
| Fedora | Replace the installation part of step 1 with [Docker's Fedora instructions](https://docs.docker.com/engine/install/fedora/); install Docker and NVIDIA Toolkit using `dnf` |

Fedora/Debian instructions follow official documentation; host test results are pending. Install GPU drivers using each distribution's procedure.
The Dockerfile and Compose files are shared; GUI package differences are in step 3.
Keep Fedora's default SELinux settings. Privileged mode disables the container's SELinux process label ([Docker details](https://docs.docker.com/reference/cli/docker/container/run/#privileged)).

## First Use

Run commands in a **host terminal**, except the container commands marked in step 5. From step 2 onward, use the repository root.

### 1. Install and Verify Docker / Compose

The installation commands below are for Ubuntu: add missing plugins to an existing Docker installation, or expand the full instructions for a new host.
Fedora/Debian users should install from the table above, then complete this step's shared user-access setup and verification.

<details>
<summary>First installation on Ubuntu: Docker Engine, Compose, and Buildx</summary>

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl nano
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
```

Based on [Docker's Ubuntu installation guide](https://docs.docker.com/engine/install/ubuntu/).

</details>

With an existing Docker installation, run `sudo apt-get update`, then select the plugin command matching its package source:

| Existing Docker on Ubuntu | Plugin installation |
|---------------------------|---------------------|
| Official repository's `docker-ce` | `sudo apt-get install -y docker-compose-plugin docker-buildx-plugin` |
| Ubuntu 24.04's `docker.io` | `sudo apt-get install -y docker-compose-v2 docker-buildx` |

This project uses the `docker compose` plugin interface from Compose v2 and later.

Set up regular-user access once; skip if already configured:

```bash
sudo groupadd -f docker
sudo usermod -aG docker "$(id -un)"
```

**Log out and log back in**, then verify:

```bash
docker compose version
docker run --rm hello-world
```

Run subsequent Compose commands as your regular user, with `${HOME}` pointing to your home directory. The `docker` group provides root-equivalent Docker administration access ([details](https://docs.docker.com/engine/install/linux-postinstall/)).

### 2. Create Local Configuration and Select a GPU

`.env.example` is the shared template. `.env` sits next to the Dockerfile, is loaded automatically by Compose, and is ignored by Git.
Create or open the local configuration at the repository root:

```bash
test -f .env || cp .env.example .env
mkdir -p .runtime/gui
nano .env
```

Use nano or another text editor. `HOST_HOME_DIR=${HOME}` mounts your home; for a workspace mount, enter its existing absolute path.
The commands above create `.runtime/gui`, a mount directory shared by all setups.

Keep all three `.yml` files and select one `COMPOSE_FILE=` setting below in `.env`; lines starting with `#` are comments:

| Option | Setting in `.env` | Host preparation |
|--------|-------------------|------------------|
| A: No GPU acceleration | `COMPOSE_FILE=docker-compose.yml` | No extra requirements |
| B: Intel/AMD integrated or discrete GPU | `COMPOSE_FILE=docker-compose.yml:docker-compose.gpu.yml` | `ls -l /dev/dri` shows `renderD*` nodes |
| C: NVIDIA discrete GPU | `COMPOSE_FILE=docker-compose.yml:docker-compose.nvidia.yml` | Working `nvidia-smi` and configured NVIDIA Container Toolkit |

GPU files are combined with the base configuration. On hybrid systems, select the setup for the GPU you intend to use.
In nano, save with `Ctrl+O`, Enter, then exit with `Ctrl+X`. Subsequent `docker compose ...` commands read this configuration automatically.

<details>
<summary>First NVIDIA setup: driver and Container Toolkit (skip if configured)</summary>

For the first GPU driver installation on Ubuntu:

```bash
sudo apt-get update
sudo apt-get install -y ubuntu-drivers-common
sudo ubuntu-drivers install
```

Save your work, reboot, and complete Secure Boot enrollment if prompted. After logging in, verify `nvidia-smi` succeeds.
Debian/Fedora users should follow their distribution's driver installation procedure.

Install Toolkit on Ubuntu/Debian; Fedora users follow the `dnf` section of the [NVIDIA guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html):

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  sudo gpg --dearmor --yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

The last command restarts Docker to activate the runtime configuration; schedule it when containers are idle on shared hosts.
The host provides the GPU driver. Install the CUDA Toolkit separately when compiling CUDA programs.

</details>

### 3. Prepare GUI Access (Skip for Command-Line Use)

From a logged-in X11/XWayland desktop terminal, install the host dependencies:

| Host | Command |
|------|---------|
| Ubuntu / Debian | `sudo apt-get update`, then `sudo apt-get install -y xauth x11-utils python3` |
| Fedora | `sudo dnf install -y xorg-x11-xauth xdpyinfo python3` |

```bash
printenv DISPLAY
./scripts/prepare-gui.sh
```

`DISPLAY` must contain the active desktop's value; Wayland sessions also need XWayland.
The script updates the display in `.env` and creates `.runtime/gui/Xauthority`; the container receives GUI authorization through a read-only mount.
Run it again after a new desktop login. Fedora packages: [xauth](https://packages.fedoraproject.org/pkgs/xorg-x11-xauth/xorg-x11-xauth/) / [xdpyinfo](https://packages.fedoraproject.org/pkgs/xdpyinfo/xdpyinfo/).

### 4. Build and Start

Inspect the mount paths and GPU settings first:

```bash
docker compose config
```

A uses the base configuration, B maps `/dev/dri`, and C includes `driver: nvidia`. Then build, start, and check the service in order:

```bash
docker compose build ros2
docker compose up -d ros2
docker compose ps
```

The first build downloads many packages. Once complete, `docker compose ps` should show `ros2` running.

### 5. Enter and Verify

On the host:

```bash
docker compose exec ros2 bash
```

Then **inside the container**:

```bash
whoami
printenv ROS_DISTRO
ros2 pkg prefix rclcpp
```

Expect `root`, `jazzy`, and an rclcpp installation path. Run `rviz2` for GUI use; `exit` leaves the shell without stopping the container.
Bash loads ROS 2 and an existing `install/setup.bash` in the current directory. Source another workspace explicitly after changing directories.

## Daily Operations and Troubleshooting

Run these at the repository root on the host, as needed:

| Task | Command / action |
|------|------------------|
| Stop / start again | `docker compose stop ros2` / `docker compose up -d ros2` |
| Enter | `docker compose exec ros2 bash` |
| After changing `.env` or GPU selection | Check `docker compose config`, then run `docker compose up -d --force-recreate ros2` |
| Remove containers, retain named volumes | `docker compose down` |
| Startup failure | Read the startup error, then `docker compose logs --tail=100 ros2` |
| Daemon stopped / socket permission denied | `sudo systemctl start docker` / log in again after joining the docker group |
| NVIDIA check | `docker compose exec ros2 nvidia-smi` |
| Display / renderer check | `docker compose exec ros2 xdpyinfo` / `docker compose exec ros2 glxinfo -B` |
| Expired GUI authorization | Run `./scripts/prepare-gui.sh --start` in a desktop terminal |
| ROS 2 diagnosis | `docker compose exec ros2 bash -ic 'ros2 doctor --report'` |
| Node.js / npm versions | `docker compose exec ros2 node --version` / `docker compose exec ros2 npm --version` |
| MuJoCo version | `docker compose exec ros2 python3 -c 'import mujoco; print(mujoco.__version__)'` |

`llvmpipe` in `glxinfo -B` means software rendering; for B/C, check the host driver and GPU selection.
After changing the Dockerfile, mirrors, or other build arguments:

```bash
docker compose build ros2
docker compose up -d --force-recreate ros2
```

The container runs as root with privileged mode and host networking/IPC; files created in the mount may belong to root.
Store source code and data in the bind mount to keep them across recreation; the container's writable layer is replaced.
VS Code caches are reused through named volumes under the same project name. `docker compose down` retains these volumes; adding `-v` removes them.

## Optional Configuration

Edit `.env`; exported shell variables take precedence. Examples: [.env.example](.env.example).

| Variable | Default / purpose |
|----------|-------------------|
| `HOST_HOME_DIR` / `COMPOSE_FILE` | Mount path / GPU selection; see step 2 |
| `COMPOSE_PROJECT_NAME` | Repository directory name; use distinct values for multiple environments on one host |
| `ROS2_IMAGE` | `ros2-jazzy-dev:local`; use separate tags for distinct builds on one host |
| `ROS_DOMAIN_ID` | `0`; communicating nodes match, independent groups use different values |
| `RMW_IMPLEMENTATION` | `rmw_fastrtps_cpp`; install the appropriate RMW package before changing |
| `ROS_AUTOMATIC_DISCOVERY_RANGE` / `ROS_STATIC_PEERS` | `SUBNET` / empty; optionally `LOCALHOST` or semicolon-separated peers |
| `TZ` / `DISPLAY` | `Asia/Shanghai` / active desktop display (updated by the script) |
| `MUJOCO_VERSION` | `3.15.0`; rebuild the image after changing |
| `RESTART_POLICY` | `no`; optionally `unless-stopped` |
| `BUILD_HTTP_PROXY` / `BUILD_HTTPS_PROXY` | Download proxies for build steps |
| `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY` / `NO_PROXY` | Runtime proxies; no proxy address by default, loopback addresses excluded |
| `UBUNTU_APT_MIRROR` / `ROS_APT_MIRROR` | Base image repositories by default; optional examples in the template |

<details>
<summary>Using MuJoCo</summary>

MuJoCo is installed for the system Python used by ROS 2 and is available through `import mujoco`.
After the GUI setup in step 3, launch the viewer from the host:

```bash
docker compose exec ros2 python3 -m mujoco.viewer
```

Drag an MJCF model into the window, or append `--mjcf=/container/path/model.xml` to open a model.
For offscreen rendering, select `MUJOCO_GL=osmesa` (software) or `MUJOCO_GL=egl` (GPU); for example, run your rendering script with `docker compose exec -e MUJOCO_GL=osmesa ros2 python3 your_script.py`.
See the [MuJoCo Python documentation](https://mujoco.readthedocs.io/en/stable/python.html).

</details>

<details>
<summary>ROS 2 networking and Fast DDS</summary>

ROS 2 discovers nodes through DDS. Communicating nodes use matching domains and network access. Assign group domains within 0–101; see [ROS_DOMAIN_ID](https://docs.ros.org/en/jazzy/Concepts/Intermediate/About-Domain-ID.html) and [discovery range](https://docs.ros.org/en/jazzy/Tutorials/Advanced/Improved-Dynamic-Discovery.html).
Compose project names distinguish containers and volumes; ROS domains distinguish communication groups. Host networking shares the host's network.
`fastdds.xml` configures Fast DDS to use UDPv4 on available interfaces and disables built-in transports (including shared memory). Restart ROS 2 nodes after editing it.

</details>

<details>
<summary>Proxies, mirrors, and direct builds</summary>

Set build proxies to addresses reachable from the build container; `127.0.0.1` refers to the container itself. Configure base-image pull proxies in the Docker daemon/client.
Mirror settings retain signature checks; ROS mirrors use binary package indexes. See [USTC Ubuntu](https://mirrors.ustc.edu.cn/help/ubuntu.html) / [TUNA ROS 2](https://mirrors.tuna.tsinghua.edu.cn/help/ros2/).
Builds use APT/pip caches. `MUJOCO_VERSION` selects the MuJoCo version; other package versions follow upstream repositories.
For a direct build, run `docker build -t ros2-jazzy-dev:local .` and pass optional settings with `--build-arg`; `.env` is used by Compose.

</details>

<details>
<summary>Refresh GUI authorization and start at desktop login</summary>

After building and verifying GUI access, run `./scripts/prepare-gui.sh --install-autostart`.
It registers `~/.config/autostart/ros2-docker-gui.desktop`, refreshing authorization at login and starting the previously built local image using `.env`.
Reinstall after moving the repository; each desktop user keeps only the last registered entry.
Disable with `rm -f ~/.config/autostart/ros2-docker-gui.desktop`.
Docker's automatic restart is controlled separately by `RESTART_POLICY`: change `unless-stopped` to `no` and recreate the container to turn it off.

</details>

<details>
<summary>Migrating an existing setup and sharing with the team</summary>

During migration, move writable-layer data you want to keep into the bind mount, then inspect the original project name:

```bash
docker ps -a --filter label=com.docker.compose.service=ros2 --format '{{.Names}}: {{.Label "com.docker.compose.project"}}'
```

Set that name as `COMPOSE_PROJECT_NAME` in `.env` and retain the GPU selection to reuse named volumes after recreation. The old project name was `ros2_docker`.
Share the Dockerfile, all three Compose files, `.env.example`, `fastdds.xml`, `scripts/`, READMEs, and ignore files.
Keep `.env`, `.runtime/`, logs, and build outputs on the local machine; use the shared-file list above when creating an archive.

</details>

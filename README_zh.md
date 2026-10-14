# ROS 2 Jazzy 通用开发镜像

[English](README.md) | 中文

基于 `osrf/ros:jazzy-desktop-full`（Ubuntu 24.04），预装 colcon、rosdep、GDB、clangd、
RViz 2、rqt、PlotJuggler、Nav2、SLAM Toolbox、MoveIt、Gazebo 集成和 ros2_control。
同时预装 Node.js 24（含 npm）和 MuJoCo 3.15.0（仿真引擎、Python 接口和查看器）。

## 宿主机要求与系统差异

使用 **x86_64（amd64）Linux + Docker Engine 系统服务 + Compose 插件**。
基础镜像平台为 `linux/amd64`，见 [OSRF 镜像说明](https://github.com/osrf/docker_images#osrf-profile)。

| 宿主机 | 使用说明 |
|--------|----------|
| Ubuntu 22.04/24.04/26.04 | 按下面的完整流程操作 |
| Debian 12/13 | 第 1 步按 [Docker Debian 安装步骤](https://docs.docker.com/engine/install/debian/)配置 Debian 软件源；NVIDIA Toolkit 使用 `apt` 分支 |
| Fedora | 第 1 步的安装部分改用 [Docker Fedora 安装步骤](https://docs.docker.com/engine/install/fedora/)，Docker 和 NVIDIA Toolkit 均使用 `dnf` 安装 |

Fedora、Debian 的安装说明根据官方文档整理，实机测试记录待补充；显卡驱动按各自系统的方法安装。
Dockerfile 和 Compose 文件共用，GUI 包名差异见第 3 步。
Fedora 保持默认 SELinux 设置即可；当前特权模式下，容器的 SELinux 进程标签被禁用，见 [Docker 说明](https://docs.docker.com/reference/cli/docker/container/run/#privileged)。

## 首次使用

除第 5 步标注的容器内命令外，均在**宿主机终端**执行；第 2 步起在仓库根目录操作。

### 1. 安装并验证 Docker / Compose

下面是 Ubuntu 的安装指令：已有 Docker 时补齐插件，新主机展开完整指令。
Fedora/Debian 按上表安装，再执行本步共同的用户权限与验证命令。

<details>
<summary>Ubuntu 首次安装 Docker Engine、Compose 和 Buildx</summary>

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

依据 [Docker Ubuntu 安装指南](https://docs.docker.com/engine/install/ubuntu/)。

</details>

已有 Docker 时，先执行 `sudo apt-get update`，再选择与现有软件源对应的补装命令：

| Ubuntu 上已有的 Docker | 补装命令 |
|------------------------|----------|
| 官方源 `docker-ce` | `sudo apt-get install -y docker-compose-plugin docker-buildx-plugin` |
| Ubuntu 24.04 系统源 `docker.io` | `sudo apt-get install -y docker-compose-v2 docker-buildx` |

本仓库使用 Compose v2 及后续版本的 `docker compose` 插件命令。

首次配置普通用户权限（已有权限可跳过）：

```bash
sudo groupadd -f docker
sudo usermod -aG docker "$(id -un)"
```

**注销并重新登录**后验证：

```bash
docker compose version
docker run --rm hello-world
```

后续以普通用户执行 Compose，`${HOME}` 对应当前用户的主目录。`docker` 组提供相当于 root 的 Docker 管理权限（[说明](https://docs.docker.com/engine/install/linux-postinstall/)）。

### 2. 创建本机配置并选择显卡

`.env.example` 是公共模板；`.env` 是与 Dockerfile 同级的本机配置，Compose 自动读取，Git 忽略它。
在仓库根目录创建或打开本机配置：

```bash
test -f .env || cp .env.example .env
mkdir -p .runtime/gui
nano .env
```

可使用 nano 或其他文本编辑器。默认 `HOST_HOME_DIR=${HOME}` 挂载自己的主目录；挂载工作空间时填写该目录的已存在绝对路径。
`.runtime/gui` 是所有方案共用的挂载目录，由上面的命令创建。

保留三个 `.yml` 文件，在 `.env` 中选择下表的一条 `COMPOSE_FILE=` 配置；以 `#` 开头的行是注释：

| 方案 | `.env` 中的配置 | 宿主机准备 |
|------|----------------|------------|
| A：不使用 GPU 加速 | `COMPOSE_FILE=docker-compose.yml` | 无额外要求 |
| B：Intel/AMD 核显或独显 | `COMPOSE_FILE=docker-compose.yml:docker-compose.gpu.yml` | `ls -l /dev/dri` 能看到 `renderD*` 节点 |
| C：NVIDIA 独显 | `COMPOSE_FILE=docker-compose.yml:docker-compose.nvidia.yml` | `nvidia-smi` 正常，并配置 NVIDIA Container Toolkit |

GPU 文件与主配置组合使用；双显卡设备按实际使用的 GPU 选择方案。
使用 nano 时按 `Ctrl+O`、回车保存，`Ctrl+X` 退出。后续的 `docker compose ...` 命令会自动读取这份配置。

<details>
<summary>NVIDIA 首次准备：驱动和 Container Toolkit（已配置可跳过）</summary>

Ubuntu 首次安装显卡驱动：

```bash
sudo apt-get update
sudo apt-get install -y ubuntu-drivers-common
sudo ubuntu-drivers install
```

保存工作并重启宿主机，按安装提示完成 Secure Boot 注册；重新登录后确认 `nvidia-smi` 正常。
Debian/Fedora 应使用各自系统的驱动安装方法。

Ubuntu/Debian 安装 Toolkit（Fedora 按 [NVIDIA 指南](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)的 `dnf` 分支操作）：

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

最后一条通过重启 Docker 使运行时配置生效，共用主机可安排在容器空闲时执行。
显卡驱动由宿主机提供；编译 CUDA 程序时另行安装 CUDA Toolkit。

</details>

### 3. 准备图形界面（仅命令行使用可跳过）

在已登录的 X11/XWayland 桌面终端中，按宿主机安装依赖：

| 宿主机 | 命令 |
|--------|------|
| Ubuntu / Debian | `sudo apt-get update`，然后 `sudo apt-get install -y xauth x11-utils python3` |
| Fedora | `sudo dnf install -y xorg-x11-xauth xdpyinfo python3` |

```bash
printenv DISPLAY
./scripts/prepare-gui.sh
```

`DISPLAY` 应有当前桌面的实际值；Wayland 会话也需 XWayland。
脚本更新 `.env` 的显示编号，生成 `.runtime/gui/Xauthority`，容器通过只读挂载获得图形授权。
重新登录桌面后再次运行脚本。Fedora 包名参考 [xauth](https://packages.fedoraproject.org/pkgs/xorg-x11-xauth/xorg-x11-xauth/) / [xdpyinfo](https://packages.fedoraproject.org/pkgs/xdpyinfo/xdpyinfo/)。

### 4. 构建并启动

先检查挂载路径和显卡配置：

```bash
docker compose config
```

配置中，A 使用基础配置，B 映射 `/dev/dri`，C 包含 `driver: nvidia`。随后依次构建、启动并查看状态：

```bash
docker compose build ros2
docker compose up -d ros2
docker compose ps
```

首次构建会下载较多软件包。完成后，`docker compose ps` 应显示 `ros2` 正在运行。

### 5. 进入容器并验证

在宿主机执行：

```bash
docker compose exec ros2 bash
```

进入后，在**容器内**执行：

```bash
whoami
printenv ROS_DISTRO
ros2 pkg prefix rclcpp
```

应依次看到 `root`、`jazzy` 和 rclcpp 安装路径。需要 GUI 时运行 `rviz2`，退出 Shell 用 `exit`，容器仍保持运行。
Bash 自动加载 ROS 2 和当前目录下已有的 `install/setup.bash`；切换工作空间后按需手动 source。

## 日常操作与排查

以下命令在宿主机仓库根目录执行，按需选择：

| 操作 | 命令 / 处理 |
|------|-------------|
| 停止 / 再次启动 | `docker compose stop ros2` / `docker compose up -d ros2` |
| 进入容器 | `docker compose exec ros2 bash` |
| 修改 `.env` 或切换显卡后 | `docker compose config` 检查，再执行 `docker compose up -d --force-recreate ros2` |
| 移除容器，保留命名卷 | `docker compose down` |
| 启动失败 | 查看启动报错，再执行 `docker compose logs --tail=100 ros2` |
| Docker 服务未运行 / socket 权限错误 | `sudo systemctl start docker` / 确认加入 docker 组后已重新登录 |
| NVIDIA 验证 | `docker compose exec ros2 nvidia-smi` |
| GUI 连接 / 渲染器验证 | `docker compose exec ros2 xdpyinfo` / `docker compose exec ros2 glxinfo -B` |
| GUI 授权过期 | 桌面终端执行 `./scripts/prepare-gui.sh --start` |
| ROS 2 诊断 | `docker compose exec ros2 bash -ic 'ros2 doctor --report'` |
| Node.js / npm 版本 | `docker compose exec ros2 node --version` / `docker compose exec ros2 npm --version` |
| MuJoCo 版本 | `docker compose exec ros2 python3 -c 'import mujoco; print(mujoco.__version__)'` |

`glxinfo -B` 显示 `llvmpipe` 表示软件渲染；B/C 方案应检查宿主机驱动和 GPU 选择。
修改 Dockerfile、镜像源或其他构建参数后，执行：

```bash
docker compose build ros2
docker compose up -d --force-recreate ros2
```

容器以 root 运行，启用 privileged 和 host 网络/IPC；挂载目录中新建文件可能归 root 所有。
将源码和数据存放在挂载目录中，可在重建后继续使用；容器可写层会随重建替换。
VS Code 缓存通过同一项目名下的命名卷复用。`docker compose down` 保留这些卷，加 `-v` 则一并删除。

## 按需配置

在 `.env` 编辑；已导出的同名 Shell 变量优先级更高。示例见 [.env.example](.env.example)。

| 变量 | 默认值 / 用途 |
|------|---------------|
| `HOST_HOME_DIR` / `COMPOSE_FILE` | 挂载目录 / 显卡方案，见第 2 步 |
| `COMPOSE_PROJECT_NAME` | 默认仓库目录名；同机多套环境设不同值 |
| `ROS2_IMAGE` | `ros2-jazzy-dev:local`；同机不同构建设不同标签 |
| `ROS_DOMAIN_ID` | `0`；通信节点保持一致，不同开发组分配不同值 |
| `RMW_IMPLEMENTATION` | `rmw_fastrtps_cpp`；切换前安装对应 RMW 包 |
| `ROS_AUTOMATIC_DISCOVERY_RANGE` / `ROS_STATIC_PEERS` | `SUBNET` / 空；可改 `LOCALHOST`，或设置分号分隔的对端地址 |
| `TZ` / `DISPLAY` | `Asia/Shanghai` / 当前桌面编号（脚本更新） |
| `MUJOCO_VERSION` | `3.15.0`；修改后重新构建镜像 |
| `RESTART_POLICY` | `no`；按需改为 `unless-stopped` |
| `BUILD_HTTP_PROXY` / `BUILD_HTTPS_PROXY` | 构建步骤的下载代理 |
| `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY` / `NO_PROXY` | 运行时代理；默认无代理地址，排除本机回环地址 |
| `UBUNTU_APT_MIRROR` / `ROS_APT_MIRROR` | 默认基础镜像软件源；模板含可选镜像站示例 |

<details>
<summary>使用 MuJoCo</summary>

MuJoCo 安装在 ROS 2 使用的系统 Python 中，可直接 `import mujoco`。
完成第 3 步图形授权后，在宿主机启动查看器：

```bash
docker compose exec ros2 python3 -m mujoco.viewer
```

可将 MJCF 模型拖入窗口，或追加 `--mjcf=/容器内路径/model.xml` 打开模型。
无窗口渲染可选 `MUJOCO_GL=osmesa`（软件）或 `MUJOCO_GL=egl`（GPU），例如通过 `docker compose exec -e MUJOCO_GL=osmesa ros2 python3 your_script.py` 运行自己的渲染脚本。
参考 [MuJoCo Python 文档](https://mujoco.readthedocs.io/en/stable/python.html)。

</details>

<details>
<summary>ROS 2 网络与 Fast DDS</summary>

ROS 2 通过 DDS 发现节点。通信节点使用相同 domain 和可达网络；可在 0–101 中按组分配，见 [ROS_DOMAIN_ID](https://docs.ros.org/en/jazzy/Concepts/Intermediate/About-Domain-ID.html) 和[发现范围](https://docs.ros.org/en/jazzy/Tutorials/Advanced/Improved-Dynamic-Discovery.html)。
Compose 项目名区分容器和卷，ROS domain 区分通信组；host 网络共享宿主机网络。
`fastdds.xml` 为 Fast DDS 配置 UDPv4 传输，使用可用网卡，并关闭内置传输（包括共享内存）；修改后重启 ROS 2 节点即可。

</details>

<details>
<summary>代理、镜像源与直接构建</summary>

构建代理填写构建容器可访问的地址，其中 `127.0.0.1` 指容器自身；基础镜像拉取代理在 Docker daemon/客户端配置。
镜像站设置保留签名校验，ROS 镜像使用二进制包索引；参考 [USTC Ubuntu](https://mirrors.ustc.edu.cn/help/ubuntu.html) / [TUNA ROS 2](https://mirrors.tuna.tsinghua.edu.cn/help/ros2/)。
构建使用 APT/pip 缓存；MuJoCo 版本由 `MUJOCO_VERSION` 指定，其余软件版本随上游更新。
直接构建命令为 `docker build -t ros2-jazzy-dev:local .`，可选参数通过 `--build-arg` 传入；`.env` 用于 Compose。

</details>

<details>
<summary>桌面登录时自动刷新授权并启动</summary>

先完成构建和 GUI 验证，再运行 `./scripts/prepare-gui.sh --install-autostart`。
入口为 `~/.config/autostart/ros2-docker-gui.desktop`；登录时按 `.env` 刷新授权，使用已构建的本地镜像启动容器。
移动仓库后重新注册；每位桌面用户只保留最后注册的一份入口。
取消：`rm -f ~/.config/autostart/ros2-docker-gui.desktop`。
Docker 自动重启由 `RESTART_POLICY` 单独控制：从 `unless-stopped` 改为 `no` 并重建容器即可关闭。

</details>

<details>
<summary>旧环境迁移与团队分发</summary>

迁移时，将容器可写层中需保留的数据移到挂载目录，并查询原项目名：

```bash
docker ps -a --filter label=com.docker.compose.service=ros2 --format '{{.Names}}: {{.Label "com.docker.compose.project"}}'
```

将输出中的项目名写入 `.env` 的 `COMPOSE_PROJECT_NAME`，保留原 GPU 方案，重建后复用原命名卷；旧版项目名为 `ros2_docker`。
分发 Dockerfile、三个 Compose 文件、`.env.example`、`fastdds.xml`、`scripts/`、README 和忽略规则。
`.env`、`.runtime/`、日志和构建产物保留在本机；共享压缩包按上述公共文件列表打包。

</details>

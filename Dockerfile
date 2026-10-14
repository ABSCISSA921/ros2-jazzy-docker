FROM osrf/ros:jazzy-desktop-full

USER root

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Avoid interactive prompts during image build.
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai

# ROS 2 environment defaults.
ENV ROS_DOMAIN_ID=0
ENV RMW_IMPLEMENTATION=rmw_fastrtps_cpp

ARG UBUNTU_APT_MIRROR
ARG ROS_APT_MIRROR

RUN set -e; for source in /etc/apt/sources.list /etc/apt/sources.list.d/*.sources /etc/apt/sources.list.d/*.list; do \
        [ -f "$source" ] || continue; \
        if [ -n "$UBUNTU_APT_MIRROR" ]; then \
            sed -i -E "s#https?://(archive|security)\.ubuntu\.com/ubuntu/?#${UBUNTU_APT_MIRROR%/}/#g" "$source"; \
        fi; \
        if [ -n "$ROS_APT_MIRROR" ]; then \
            sed -i -E "s#https?://packages\.ros\.org/ros2/ubuntu/?#${ROS_APT_MIRROR%/}/#g" "$source"; \
            if grep -Fq "${ROS_APT_MIRROR%/}/" "$source"; then \
                sed -i -E 's/^(Types:.*) deb-src/\1/; /^deb-src /s/^/# /' "$source"; \
            fi; \
        fi; \
    done

RUN printf 'Acquire::Retries "3";\n' > /etc/apt/apt.conf.d/80-retries && \
    apt-get update && \
    apt-get install -y \
        sudo \
        software-properties-common \
        wget \
        gnupg \
        curl \
        ca-certificates && \
    apt-get install -y \
        ros-dev-tools \
        python3-pip \
        python3-rosdep \
        python3-vcstool \
        python3-colcon-common-extensions \
        build-essential \
        cmake \
        ninja-build \
        pkg-config \
        gdb \
        clangd \
        clang-format \
        git \
        vim \
        jq \
        bash-completion \
        iproute2 \
        net-tools \
        udev \
        usbutils \
        pciutils \
        libserial-dev \
        mesa-utils \
        x11-utils \
        libglvnd0 \
        libgl1 \
        libglx0 \
        libegl1 \
        vulkan-tools \
        libgl1-mesa-dri \
        libglx-mesa0 \
        libegl-mesa0 \
        mesa-vulkan-drivers && \
    rm -rf /var/lib/apt/lists/*

RUN --mount=type=cache,id=ros2-jazzy-apt-lists,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=cache,id=ros2-jazzy-apt-archives,target=/var/cache/apt,sharing=locked \
    mv /etc/apt/apt.conf.d/docker-clean /tmp/docker-clean && \
    apt-get update && \
    apt-get install -y \
        'ros-jazzy-rqt-*' \
        ros-jazzy-rviz2 \
        ros-jazzy-plotjuggler-ros \
        ros-jazzy-robot-localization \
        ros-jazzy-navigation2 \
        ros-jazzy-nav2-bringup \
        ros-jazzy-slam-toolbox \
        ros-jazzy-moveit \
        ros-jazzy-ros-gz \
        ros-jazzy-ros2-control \
        ros-jazzy-ros2-controllers \
        ros-jazzy-joint-state-publisher \
        ros-jazzy-joint-state-publisher-gui \
        ros-jazzy-xacro \
        ros-jazzy-urdf \
        ros-jazzy-geometry-msgs \
        ros-jazzy-sensor-msgs \
        ros-jazzy-nav-msgs \
        ros-jazzy-tf2-ros \
        ros-jazzy-tf2-geometry-msgs \
        ros-jazzy-message-filters \
        ros-jazzy-rosbridge-server \
        ros-jazzy-joy \
        ros-jazzy-teleop-twist-keyboard \
        ros-jazzy-teleop-twist-joy \
        ros-jazzy-imu-complementary-filter \
        ros-jazzy-imu-filter-madgwick \
        ros-jazzy-control-msgs \
        ros-jazzy-action-msgs && \
    mv /tmp/docker-clean /etc/apt/apt.conf.d/docker-clean

RUN --mount=type=cache,id=ros2-jazzy-apt-lists,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=cache,id=ros2-jazzy-apt-archives,target=/var/cache/apt,sharing=locked \
    mv /etc/apt/apt.conf.d/docker-clean /tmp/docker-clean && \
    mkdir -p /etc/apt/keyrings && \
    curl --retry 3 -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_24.x nodistro main" > /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install -y nodejs libglfw3 libosmesa6 && \
    node --version && npm --version && \
    mv /tmp/docker-clean /etc/apt/apt.conf.d/docker-clean

# Install MuJoCo for the system Python used by ROS 2 node entry points.
# Keep the NumPy 1.x ABI used by the Ubuntu 24.04 ROS packages.
ARG MUJOCO_VERSION=3.15.0
RUN --mount=type=cache,id=ros2-jazzy-pip,target=/root/.cache/pip,sharing=locked \
    python3 -m pip install --break-system-packages "numpy<2" "mujoco==${MUJOCO_VERSION}" && \
    python3 -c "import mujoco; m = mujoco.MjModel.from_xml_string('<mujoco><worldbody/></mujoco>'); d = mujoco.MjData(m); mujoco.mj_step(m, d); print('MuJoCo', mujoco.__version__)"

RUN if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then rosdep init; fi && \
    rosdep update

RUN echo '# Colorized bash' >> /root/.bashrc && \
    echo 'export TERM=xterm-256color' >> /root/.bashrc && \
    echo "alias ls='ls --color=auto'" >> /root/.bashrc && \
    echo "alias grep='grep --color=auto'" >> /root/.bashrc && \
    echo "alias ll='ls -alF --color=auto'" >> /root/.bashrc && \
    echo 'PS1="${debian_chroot:+($debian_chroot)}\[\\033[01;32m\]\u@\h\[\\033[00m\]:\[\\033[01;34m\]\w\[\\033[00m\]\$ "' >> /root/.bashrc && \
    echo '' >> /root/.bashrc && \
    echo '# ROS 2 environment' >> /root/.bashrc && \
    echo 'export ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-0}' >> /root/.bashrc && \
    echo 'export RMW_IMPLEMENTATION=${RMW_IMPLEMENTATION:-rmw_fastrtps_cpp}' >> /root/.bashrc && \
    echo 'source /opt/ros/jazzy/setup.bash' >> /root/.bashrc && \
    echo 'if [ -f "$PWD/install/setup.bash" ]; then source "$PWD/install/setup.bash"; fi' >> /root/.bashrc

WORKDIR /workspace

# Original upstream: https://github.com/HydrogenZp/common-ros2-jazzy-docker
# Set org.opencontainers.image.source to the team repository when publishing.
LABEL org.opencontainers.image.description="Common ROS 2 Jazzy Docker Image with pre-configured tools"
LABEL org.opencontainers.image.licenses=MIT

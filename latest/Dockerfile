FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive

# Create a user account lime (UID 1027) that the container will run as
RUN useradd -m -u 1027 -s /bin/bash citra

# Update repos + upgrade system
RUN apt-get update && apt-get -y full-upgrade

# Install package dependencies
RUN apt-get install -y \
    # Tools
    build-essential \
    ccache \
    clang-19 \
    clang-format-19 \
    cmake \
    curl \
    file \
    git \
    libc++-19-dev \
    lld \
    llvm-19 \
    ninja-build \
    python3-pip \
    ruby \
    wget \
    unzip \
    zip \
    # FFmpeg
    ffmpeg \
    libavcodec-dev \
    libavdevice-dev \
    libavfilter-dev \
    libavformat-dev \
    libswresample-dev \
    libswscale-dev \
    # Qt 6
    qt6-base-dev \
    qt6-base-private-dev \
    libqt6opengl6-dev \
    qt6-multimedia-dev \
    qt6-l10n-tools \
    qt6-tools-dev \
    qt6-tools-dev-tools \
    libgl-dev \
    # glslang
    glslang-dev \
    glslang-tools \
    # Other libraries
    libsdl2-dev

# Create Clang symlinks
RUN ln -s /usr/bin/clang-19 /usr/bin/clang
RUN ln -s /usr/bin/clang++-19 /usr/bin/clang++
RUN ln -s /usr/bin/clang-format-19 /usr/bin/clang-format

# Ensure that lupdate is in path
RUN ln -s /usr/lib/qt6/bin/lupdate /usr/local/bin/lupdate

# Download Transifex client
RUN curl -o- https://raw.githubusercontent.com/transifex/cli/master/install.sh | bash
RUN mv /tx /usr/bin/

# Download tools for building AppImages
RUN wget https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
RUN wget https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage
RUN wget https://github.com/linuxdeploy/linuxdeploy-plugin-checkrt/releases/download/continuous/linuxdeploy-plugin-checkrt-x86_64.sh
RUN chmod a+x linuxdeploy-x86_64.AppImage
RUN chmod a+x linuxdeploy-plugin-qt-x86_64.AppImage
RUN chmod a+x linuxdeploy-plugin-checkrt-x86_64.sh

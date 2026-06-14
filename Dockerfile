FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive

## 1. Create a user account 'citra' (UID 1027) that the container will run as
RUN useradd -m -u 1027 -s /bin/bash citra

## 2. Update repos + upgrade system
RUN apt-get update && apt-get -y full-upgrade

## 3. Install package dependencies
RUN apt-get install -y \
    # Tools
    build-essential \
    ccache \
    clang-19 \
    clang-format-19 \
    cmake \
    curl \
    file \
    gcc \
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
    qt6-translations-l10n \
    libgl-dev \
    # glslang
    glslang-dev \
    glslang-tools \
    # Other libraries
    libsdl2-dev \
    # MXE build tools
    7zip \
    autoconf \
    automake \
    autopoint \
    bison \
    flex \
    gperf \
    intltool \
    libssl-dev \
    libtool-bin \
    lzip \
    python-is-python3 \
    python3-mako \
    python3-setuptools \
    wine64-tools

# Create Clang symlinks
RUN ln -s /usr/bin/clang-19 /usr/bin/clang
RUN ln -s /usr/bin/clang++-19 /usr/bin/clang++
RUN ln -s /usr/bin/clang-format-19 /usr/bin/clang-format

# Ensure that lupdate is in PATH
RUN ln -s /usr/lib/qt6/bin/lupdate /usr/local/bin/lupdate

## 4. Set up MXE build environment
RUN git clone https://github.com/mxe/mxe
WORKDIR /mxe
RUN git checkout --detach 0c8fa7f25e1d46321a3dda7103396c4c50a65ed8 # April 29th 2026
# Note: JOBS = parallel jobs for *each* package, -j = how many packag*es* to build in parallel
RUN make boost nsis qt6-qtbase qt6-qtmultimedia qt6-qttools qt6-qttranslations \
        -j1 \
        JOBS=$(nproc) \
        MXE_TARGETS='x86_64-w64-mingw32.shared' \
        MXE_PLUGIN_DIRS=plugins/gcc15 \
        MXE_USE_CCACHE= && \
    rm -rf /mxe/pkg/
# TODO: Merge into above command after https://github.com/mxe/mxe/issues/3314 is fixed
RUN make cryptopp \
        -j1 \
        JOBS=$(nproc) \
        MXE_TARGETS='x86_64-w64-mingw32.shared' \
        MXE_PLUGIN_DIRS=plugins/gcc15 \
        MXE_USE_CCACHE= && \
    rm -rf /mxe/pkg/
RUN printf "\nMXE_PLUGIN_DIRS=plugins/gcc15\nMXE_USE_CCACHE=" >> /mxe/settings.mk
RUN echo 'export PATH="/mxe/usr/bin:${PATH}"' >> /etc/bash.bashrc

WORKDIR /

## 5. Download Transifex client
RUN curl -o- https://raw.githubusercontent.com/transifex/cli/master/install.sh | bash
RUN mv /tx /usr/bin/

## 6. Download AppImage tools
RUN wget https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
RUN wget https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage
RUN wget https://github.com/linuxdeploy/linuxdeploy-plugin-checkrt/releases/download/continuous/linuxdeploy-plugin-checkrt-x86_64.sh
RUN chmod a+x linuxdeploy-x86_64.AppImage
RUN chmod a+x linuxdeploy-plugin-qt-x86_64.AppImage
RUN chmod a+x linuxdeploy-plugin-checkrt-x86_64.sh

## 7. Install ktlint (and by extension, Homebrew, as it's where ktlint is packaged)
# Standard Homebrew setup
RUN touch /.dockerenv # Allows Homebrew to run as root, which is otherwise prohibited
RUN yes | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
RUN test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && \
    echo "eval \"\$($(brew --prefix)/bin/brew shellenv)\"" >> ~/.bashrc
# Install ktlint
RUN /home/linuxbrew/.linuxbrew/bin/brew install -y ktlint

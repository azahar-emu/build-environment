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
    libclang-19-dev \
    libssl-dev \
    libtool-bin \
    lzip \
    python-is-python3 \
    python3-mako \
    python3-setuptools \
    wine64-tools \
    # Dev convenience
    fastfetch \
    htop \
    vim-tiny

# Create convenient symlinks
RUN ln -s /usr/bin/fastfetch /usr/local/bin/neofetch
RUN ln -s /usr/bin/vim.tiny /usr/local/bin/vim

# Create Clang symlinks
RUN ln -s /usr/bin/clang-19 /usr/bin/clang
RUN ln -s /usr/bin/clang++-19 /usr/bin/clang++
RUN ln -s /usr/bin/clang-format-19 /usr/bin/clang-format
RUN ln -s /usr/bin/llvm-ar-19 /usr/bin/llvm-ar

# Ensure that lupdate is in PATH
RUN ln -s /usr/lib/qt6/bin/lupdate /usr/local/bin/lupdate


## 4. Set up MXE build environment
RUN git config --global user.name "Citra" && \
    git config --global user.email "citra"

RUN git clone https://github.com/mxe/mxe
WORKDIR /mxe
RUN git checkout --detach de7d7a0ad6e016077cd9d73c1297780ef2604401 # June 3rd 2026
RUN git remote add llvm-plugin https://github.com/kleisauke/mxe && \
    git fetch llvm-plugin
RUN git cherry-pick fd5d995b37efe412dff7ec76177e8cb14f5ea8dc # Base LLVM plugin,  June 5th 2026
RUN git cherry-pick 2908b4703ce16b6b6d8f4b5df1dc0b804ac4ce7d # Meson wrapper improvements,  June 5th 2026

# Note: JOBS = parallel jobs for *each* package, -j = how many packag*es* to build in parallel
# 4.1: Make stuff that requires GCC to work properly
RUN make nsis \
        -j1 \
        JOBS=$(nproc) \
        MXE_TARGETS='x86_64-w64-mingw32.shared' \
        MXE_PLUGIN_DIRS=plugins/gcc16 \
        MXE_USE_CCACHE= && \
    rm -rf /mxe/pkg/
# 4.2: Make initial MXE LLVM
RUN make llvm \
        -j1 \
        JOBS=$(nproc) \
        MXE_TARGETS=$(/usr/share/misc/config.guess) \
        MXE_PLUGIN_DIRS=plugins/gcc16 \
        MXE_USE_CCACHE= && \
    rm -rf /mxe/pkg/
# 4.3: Apply patches for building with LLVM plugin
#      (has be done after we're done with GCC, unless we want to
#       waste time making the recipe support both)
RUN mkdir /root/patches/       # Why are you this way, Docker.
COPY ./patches/ /root/patches/

RUN git apply --index /root/patches/mxe-llvm/*.patch && \
    git commit -m "Apply LLVM plugin build fixes"
# 4.4: Make MinGW LLVM
RUN make llvm \
        -j1 \
        JOBS=$(nproc) \
        MXE_TARGETS='x86_64-w64-mingw32.shared' \
        MXE_PLUGIN_DIRS=plugins/llvm-mingw \
        MXE_USE_CCACHE= && \
    rm -rf /mxe/pkg/
RUN ln -s /mxe/usr/x86_64-w64-mingw32.shared/x86_64-w64-mingw32/lib/libunwind.dll.a \
          /mxe/usr/x86_64-w64-mingw32.shared/x86_64-w64-mingw32/lib/libunwind.a
RUN ln -s /mxe/usr/x86_64-w64-mingw32.shared/x86_64-w64-mingw32/lib/libc++.dll.a \
          /mxe/usr/x86_64-w64-mingw32.shared/x86_64-w64-mingw32/lib/libc++.a
# 4.5: Make libgmp without problematic .la file
RUN make gmp \
        -j1 \
        JOBS=$(nproc) \
        MXE_TARGETS='x86_64-w64-mingw32.shared' \
        MXE_PLUGIN_DIRS=plugins/llvm-mingw \
        MXE_USE_CCACHE= && \
    rm /mxe/usr/x86_64-w64-mingw32.shared/lib/libgmp.la && \
    rm -rf /mxe/pkg/
# 4.6: Make all of the Qt stuff we need
RUN make qt6-qtbase qt6-qtmultimedia qt6-qttools qt6-qttranslations \
        -j1 \
        JOBS=$(nproc) \
        MXE_TARGETS='x86_64-w64-mingw32.shared' \
        MXE_PLUGIN_DIRS=plugins/llvm-mingw \
        MXE_USE_CCACHE= && \
    rm -rf /mxe/pkg/
RUN printf "\nMXE_PLUGIN_DIRS=plugins/llvm-mingw\nMXE_USE_CCACHE=" >> /mxe/settings.mk
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
    echo "eval \"\$($(brew --prefix)/bin/brew shellenv)\"" >> /etc/bash.bashrc
# Install ktlint
RUN /home/linuxbrew/.linuxbrew/bin/brew install -y ktlint

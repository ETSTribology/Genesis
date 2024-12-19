# Use a base image with Python 3.9 and CUDA support
ARG BASE_IMAGE=nvidia/cuda:11.3.1-cudnn8-runtime-ubuntu20.04
FROM ${BASE_IMAGE}

# Set environment variables
ARG PYTHON_VERSION=3.9
ARG CMAKE_VERSION=3.26.1
ARG GCC_VERSION=11
ARG ENABLE_LUISARENDER=ON
ARG ENABLE_MOTION_PLANNING=ON
ARG ENABLE_SURFACE_RECONSTRUCTION=ON
ENV DEBIAN_FRONTEND=noninteractive
ENV CONDA_DIR=/opt/conda
ENV PATH="$CONDA_DIR/bin:$PATH"

# Install basic dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    manpages-dev \
    software-properties-common \
    curl \
    git \
    cmake \
    libvulkan-dev \
    zlib1g-dev \
    libglu1-mesa-dev \
    xorg-dev \
    libsnappy-dev \
    python3-pip \
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-dev \
    python${PYTHON_VERSION}-distutils \
    && apt-get clean

# Install GCC/G++ version
RUN add-apt-repository ppa:ubuntu-toolchain-r/test && apt-get update && \
    apt-get install -y gcc-${GCC_VERSION} g++-${GCC_VERSION} && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-${GCC_VERSION} 110 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-${GCC_VERSION} 110

# Install Rust for SplashSurf
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:$PATH"

# Install Miniconda (for Conda dependencies)
RUN curl -fsSL https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -o Miniconda3.sh && \
    bash Miniconda3.sh -b -p $CONDA_DIR && \
    rm Miniconda3.sh && \
    conda update -y conda

# Install Conda dependencies
RUN conda install -c conda-forge gcc=${GCC_VERSION} gxx=${GCC_VERSION} cmake=${CMAKE_VERSION} zlib libuuid patchelf vulkan-tools vulkan-headers -y

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install pybind11[global] splashsurf genesis-world

# Clone Genesis repository
WORKDIR /app
ARG GENESIS_REPO=https://github.com/genesis-simulator/genesis.git
RUN git clone --recursive ${GENESIS_REPO} . && \
    git submodule update --init --recursive

# Compile LuisaRender for Ray Tracing (Optional)
WORKDIR /app/ext/LuisaRender
RUN if [ "${ENABLE_LUISARENDER}" = "ON" ]; then \
    cmake -S . -B build \
        -D CMAKE_BUILD_TYPE=Release \
        -D LUISA_COMPUTE_DOWNLOAD_NVCOMP=ON \
        -D LUISA_COMPUTE_ENABLE_GUI=OFF \
        -D PYTHON_VERSIONS=${PYTHON_VERSION} && \
    cmake --build build -j$(nproc); \
    fi

# Compile Genesis with optional features
WORKDIR /app
RUN cmake -S . -B build \
    -D CMAKE_BUILD_TYPE=Release \
    -D ENABLE_RAY_TRACING=${ENABLE_LUISARENDER} \
    -D ENABLE_MOTION_PLANNING=${ENABLE_MOTION_PLANNING} \
    -D ENABLE_SURFACE_RECONSTRUCTION=${ENABLE_SURFACE_RECONSTRUCTION} \
    -D PYTHON_VERSIONS=${PYTHON_VERSION} && \
    cmake --build build -j$(nproc)

# Set the entrypoint
ENTRYPOINT ["python3"]

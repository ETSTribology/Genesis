# Use a base image with Python 3.9 and CUDA support
FROM nvidia/cuda:12.0-base-ubuntu20.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHON_VERSION=3.9
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
    python3.9 \
    python3.9-dev \
    python3.9-distutils \
    && apt-get clean

# Install GCC/G++ version 11
RUN add-apt-repository ppa:ubuntu-toolchain-r/test && apt-get update && \
    apt-get install -y gcc-11 g++-11 && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 110 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-11 110

# Install Rust for SplashSurf
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:$PATH"

# Install Miniconda (for Conda dependencies)
RUN curl -fsSL https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -o Miniconda3.sh && \
    bash Miniconda3.sh -b -p $CONDA_DIR && \
    rm Miniconda3.sh && \
    conda update -y conda

# Install Conda dependencies
RUN conda install -c conda-forge gcc=11 gxx=11 cmake=3.26.1 zlib libuuid patchelf vulkan-tools vulkan-headers -y

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install pybind11[global] splashsurf genesis-world

# Clone Genesis repository
WORKDIR /app
RUN git clone --recursive https://github.com/genesis-simulator/genesis.git . && \
    git submodule update --init --recursive

# Compile LuisaRender for Ray Tracing
WORKDIR /app/ext/LuisaRender
RUN cmake -S . -B build \
    -D CMAKE_BUILD_TYPE=Release \
    -D LUISA_COMPUTE_DOWNLOAD_NVCOMP=ON \
    -D LUISA_COMPUTE_ENABLE_GUI=OFF \
    -D PYTHON_VERSIONS=3.9 && \
    cmake --build build -j$(nproc)

# Compile Genesis
WORKDIR /app
RUN cmake -S . -B build \
    -D CMAKE_BUILD_TYPE=Release \
    -D ENABLE_RAY_TRACING=ON \
    -D ENABLE_MOTION_PLANNING=ON \
    -D ENABLE_SURFACE_RECONSTRUCTION=ON \
    -D PYTHON_VERSIONS=3.9 && \
    cmake --build build -j$(nproc)

# Expose any necessary ports (e.g., for the interactive viewer)
EXPOSE 8080

# Set the entrypoint
ENTRYPOINT ["python3"]

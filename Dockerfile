# Use a base image with Python 3.9 and CUDA support
ARG BASE_IMAGE=pytorch/pytorch:2.5.1-cuda12.4-cudnn9-devel
FROM ${BASE_IMAGE}

# Set environment variables
ARG PYTHON_VERSION=3.9
ARG CMAKE_VERSION=3.26.1
ARG GCC_VERSION=11
ARG ENABLE_LUISARENDER=OFF
ARG ENABLE_MOTION_PLANNING=ON
ARG ENABLE_SURFACE_RECONSTRUCTION=ON
ENV DEBIAN_FRONTEND=noninteractive
ENV CONDA_DIR=/opt/conda
ENV PATH="$CONDA_DIR/bin:$PATH:/root/.cargo/bin"

# Install basic dependencies
RUN apt-get update
RUN apt-get upgrade
RUN apt-get install -y build-essential
RUN apt-get install -y manpages-dev
RUN apt-get install -y software-properties-common
RUN apt-get install -y curl
RUN apt-get install -y git
RUN apt-get install -y vim 
RUN apt-get install -y tar 
RUN apt-get install -y xz-utils
RUN apt-get install -y cmake
RUN apt-get install -y libvulkan-dev
RUN apt-get install -y zlib1g-dev
RUN apt-get install -y libglu1-mesa-dev
RUN apt-get install -y xorg-dev
RUN apt-get install -y libsnappy-dev
RUN apt-get install -y python3-pip
RUN apt-get install -y python${PYTHON_VERSION}
RUN apt-get install -y python${PYTHON_VERSION}-dev
RUN apt-get install -y python${PYTHON_VERSION}-distutils
RUN apt-get install -y libzstd-dev
RUN apt-get install -y libbz2-dev
RUN apt-get install -y libpng-dev
RUN apt-get install -y libtiff-dev
RUN apt-get install -y libjpeg-dev
RUN apt-get install -y libglvnd0 
RUN apt-get install -y libgl1 
RUN apt-get install -y libglx0 
RUN apt-get install -y libegl1 
RUN apt-get install -y libgles2 
RUN apt-get install -y ffmpeg
RUN apt-get install -y python3-opengl
RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/*

# Install GUI module dependencies
RUN apt-get update
RUN apt-get install -y libopencv-dev
RUN apt-get install -y libglfw3-dev
RUN apt-get install -y libxinerama-dev
RUN apt-get install -y libxcursor-dev
RUN apt-get install -y libxi-dev
RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/*

# Install GCC/G++ version
RUN add-apt-repository ppa:ubuntu-toolchain-r/test
RUN apt-get update
RUN apt-get install -y gcc-${GCC_VERSION}
RUN apt-get install -y g++-${GCC_VERSION}
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-${GCC_VERSION} 110
RUN update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-${GCC_VERSION} 110
RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/*

# Install Rust for SplashSurf
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
RUN cargo install splashsurf

# Install Miniconda (for Conda dependencies)
RUN curl -fsSL https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -o Miniconda3.sh
RUN bash Miniconda3.sh -b -p $CONDA_DIR
RUN rm Miniconda3.sh
RUN conda update -y conda

# Install Conda dependencies
RUN conda install -c conda-forge gcc=${GCC_VERSION}
RUN conda install -c conda-forge gxx=${GCC_VERSION}
RUN conda install -c conda-forge cmake=${CMAKE_VERSION}
RUN conda install -c conda-forge zlib
RUN conda install -c conda-forge libuuid
RUN conda install -c conda-forge patchelf
RUN conda install -c conda-forge vulkan-tools
RUN conda install -c conda-forge vulkan-headers
RUN conda clean --all --yes

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip
RUN pip install pillow
RUN pip install pybind11[global]
RUN pip install pyrender
RUN pip install PyOpenGL==3.1.7

# Clone Genesis repository
WORKDIR /app
ARG GENESIS_REPO=https://github.com/Genesis-Embodied-AI/Genesis.git
RUN git clone --recursive ${GENESIS_REPO} .
RUN git submodule update --init --recursive
RUN pip install --no-cache-dir -e .

# Apply fixes to Rust code to resolve warnings and potential errors
WORKDIR /app/genesis/ext/LuisaRender

# Compile LuisaRender for Ray Tracing (Optional)
RUN if [ "${ENABLE_LUISARENDER}" = "ON" ]; then \
    if [ -f "CMakeLists.txt" ]; then \
        cmake -S . -B build \
            -D CMAKE_BUILD_TYPE=Release \
            -D LUISA_COMPUTE_DOWNLOAD_NVCOMP=ON \
            -D LUISA_COMPUTE_ENABLE_GUI=ON \
            -D PYTHON_VERSIONS=${PYTHON_VERSION} && \
        cmake --build build -j$(nproc); \
    else \
        echo "CMakeLists.txt not found in /app/genesis/ext/LuisaRender. Skipping build."; \
        exit 1; \
    fi; \
fi

# Set the entrypoint
ENTRYPOINT ["python3"]

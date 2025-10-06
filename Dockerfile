FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

# Install all build tools + runtime dependencies in one layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    cmake \
    git \
    curl \
    zip \
    unzip \
    tar \
    ninja-build \
    libusb-1.0-0-dev \
    libudev-dev \
    libopencv-dev \
    pkg-config \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

RUN update-ca-certificates

RUN pip3 install --no-cache-dir --upgrade "cmake>=3.29"

# Build depthai-core
WORKDIR /opt
RUN git clone --branch v3.0.0 --recursive https://github.com/luxonis/depthai-core.git
ENV VCPKG_FORCE_SYSTEM_BINARIES=1
RUN cmake -S depthai-core -B depthai-core/build \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local
RUN cmake --build depthai-core/build --target install --parallel $(nproc)

# Add runtime USB support
RUN apt-get update && apt-get install -y --no-install-recommends \
    udev \
    libusb-1.0-0 \
    usbutils \
    && rm -rf /var/lib/apt/lists/*

# Add udev rule for Movidius (OAK / MyriadX)
RUN mkdir -p /etc/udev/rules.d \
    && echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="03e7", MODE="0666"' > /etc/udev/rules.d/80-movidius.rules

# Build your app
WORKDIR /workspace
COPY . .
RUN cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -G Ninja
RUN cmake --build build --parallel $(nproc)

CMD ["./build/myapp"]

FROM espressif/idf:release-v5.1

# Install additional tools if needed
RUN apt-get update && apt-get install -y \
    git \
    wget \
    flex \
    bison \
    gperf \
    python3 \
    python3-pip \
    python3-venv \
    cmake \
    ninja-build \
    ccache \
    libffi-dev \
    libssl-dev \
    dfu-util \
    libusb-1.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /project

# Set environment variables
ENV IDF_PATH=/opt/esp/idf
ENV PATH="${IDF_PATH}/tools:${PATH}"

# Create a non-root user for development
ARG USER_ID=1000
ARG GROUP_ID=1000
RUN groupadd -g ${GROUP_ID} developer && \
    useradd -m -u ${USER_ID} -g developer developer && \
    chown -R developer:developer /project

USER developer

# Default command
CMD ["/bin/bash"]

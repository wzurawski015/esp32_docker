FROM espressif/idf:release-v5.3
RUN apt-get update && apt-get install -y --no-install-recommends doxygen graphviz ca-certificates git curl      && rm -rf /var/lib/apt/lists/*
ENV IDF_TARGET=esp32c6 LC_ALL=C.UTF-8 LANG=C.UTF-8 USE_CCACHE=1
WORKDIR /work

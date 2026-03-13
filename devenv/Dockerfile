FROM --platform=linux/arm64 ubuntu:22.04

ARG UID
ARG GID

RUN apt-get update && apt-get install -y \
    build-essential clang flex bison g++ gawk gettext git \
    libncurses-dev libssl-dev python3-distutils rsync unzip zlib1g-dev \
    file wget swig libelf-dev python3-setuptools \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -g ${GID} builder 2>/dev/null || true && \
    useradd -u ${UID} -g ${GID} -m -s /bin/bash builder

WORKDIR /build
USER builder

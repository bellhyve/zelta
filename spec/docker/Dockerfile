FROM debian:bookworm

RUN apt-get update && \
    apt-get install -y zfsutils-linux && \
    rm -rf /var/lib/apt/lists/*

# Your test setup
COPY . /workspace
WORKDIR /workspace

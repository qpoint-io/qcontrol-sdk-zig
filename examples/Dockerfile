FROM us-docker.pkg.dev/qpoint-edge/public/qcontrol:latest AS qcontrol

FROM debian:bookworm-slim

# Build arguments for version pinning
ARG ZIG_VERSION=0.15.2
ARG TARGETARCH

# Install build essentials and dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    curl \
    wget \
    xz-utils \
    ca-certificates \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code native binary
RUN curl -fsSL https://claude.ai/install.sh | bash

# Ensure Claude is in PATH for all shells
ENV PATH="/root/.local/bin:${PATH}"

# Copy qcontrol binary from upstream image
COPY --from=qcontrol /usr/local/bin/qcontrol /usr/local/bin/qcontrol

# Install Zig (architecture-aware)
RUN ZIGARCH=$(case "${TARGETARCH}" in "arm64") echo "aarch64" ;; *) echo "x86_64" ;; esac) && \
    curl -fsSL "https://ziglang.org/download/${ZIG_VERSION}/zig-${ZIGARCH}-linux-${ZIG_VERSION}.tar.xz" | tar -C /opt -xJf - && \
    ln -s /opt/zig-${ZIGARCH}-linux-${ZIG_VERSION}/zig /usr/local/bin/zig

# Copy SDK source
WORKDIR /workspace
COPY . .

# Build examples to verify everything works, then clean build cache
RUN cd examples && make clean && make all && make clean

# Add MOTD
COPY examples/motd.txt /etc/motd
RUN echo 'cat /etc/motd' >> /root/.bashrc

# Set default working directory for interactive shell
WORKDIR /workspace/examples

CMD ["/bin/bash"]

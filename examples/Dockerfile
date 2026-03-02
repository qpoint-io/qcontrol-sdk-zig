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
    && rm -rf /var/lib/apt/lists/*

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

CMD ["/bin/bash"]

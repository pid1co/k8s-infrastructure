# Multi-stage build for ClawShell
# https://github.com/clawshell/clawshell

FROM rust:1.90-slim-bookworm AS builder

RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy source code
COPY . .

# Build release binary
RUN cargo build --release

# Runtime stage
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/clawshell /usr/local/bin/clawshell

# Create config directory
RUN mkdir -p /etc/clawshell

EXPOSE 8081

ENTRYPOINT ["clawshell", "start"]
CMD ["-c", "/etc/clawshell/config.toml"]

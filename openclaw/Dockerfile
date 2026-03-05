# syntax=docker/dockerfile:1
FROM ubuntu:24.04 AS builder

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        git \
        libfreetype6-dev \
        libpng-dev \
        libsdl2-dev \
        libsdl2-gfx-dev \
        libsdl2-image-dev \
        libsdl2-mixer-dev \
        libsdl2-ttf-dev \
        zlib1g-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/openclaw

# Pin to a specific commit for reproducible builds.
# Update OPENCLAW_REF to the desired commit SHA or tag.
ARG OPENCLAW_REF=master
RUN git clone --depth 1 https://github.com/pjasicek/OpenClaw.git . \
    && git fetch --depth 1 origin "${OPENCLAW_REF}" \
    && git checkout FETCH_HEAD \
    && make

FROM ubuntu:24.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends \
        libfreetype6 \
        libpng16-16t64 \
        libsdl2-2.0-0 \
        libsdl2-gfx-1.0-0 \
        libsdl2-image-2.0-0 \
        libsdl2-mixer-2.0-0 \
        libsdl2-ttf-2.0-0 \
        zlib1g \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/openclaw

COPY --from=builder /opt/openclaw/OpenClaw /opt/openclaw/OpenClaw
COPY --from=builder /opt/openclaw/ASSETS /opt/openclaw/ASSETS

VOLUME ["/data"]

CMD ["/opt/openclaw/OpenClaw"]

# syntax=docker/dockerfile:1
# Use the pre-built OpenClaw image as the base.
# The multi-stage build (compile from source) is no longer needed
# because the base image already ships the compiled game binary
# and all required runtime libraries.
# hadolint ignore=DL3007
FROM ghcr.io/openclaw/openclaw:latest

# Mount point for the proprietary CLAW.REZ game asset.
# Place CLAW.REZ in ./data on the host before running.
VOLUME ["/data"]

CMD ["/opt/openclaw/OpenClaw"]

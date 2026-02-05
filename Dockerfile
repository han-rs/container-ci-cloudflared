# Build container

# Base image
ARG GO_BASE_IMAGE=1.25.7-alpine3.23

# Image METADATA
ARG IMAGE_BUILD_DATE=1970-01-01T00:00:00+00:00
ARG IMAGE_VCS_REF=00000000

# Versions
# These versions should be kept in sync with the ones in .github/workflows/ci.yaml.
ARG CLOUDFLARED_VERSION=2026.1.2
ARG CLOUDFLARED_COMMIT=d7c62aed71e2aaccbe9230b9928f0e52a53f11c4

# Non-root user and group IDs
ARG UID=65532
ARG GID=65532

# Proxy settings
ARG http_proxy=""
ARG https_proxy=""

ARG TARGETARCH

FROM --platform=linux/${TARGETARCH} golang:${GO_BASE_IMAGE} AS builder

ARG http_proxy
ARG https_proxy

RUN set -e && \
    apk --no-cache add \
    ca-certificates=20251003-r0 \
    git=2.52.0-r0 \
    build-base=0.5-r3

# Dont warn about detached head state
RUN set -e && \
    git config --global advice.detachedHead false

WORKDIR /src

RUN set -e \
    && \
    git clone --depth 1 --recurse-submodules -j8 https://github.com/cloudflare/cloudflared

WORKDIR /src/cloudflared

ARG CLOUDFLARED_COMMIT

RUN set -e \
    && \
    git checkout "${CLOUDFLARED_COMMIT}"

# From this point on, step(s) are duplicated per-architecture
ENV GO111MODULE=on CGO_ENABLED=0

ARG TARGETARCH

# Fixes execution on linux/arm/v6 for devices that don't support armv7 binaries
RUN if [ "${TARGETARCH}" = "arm/v6" ]; then export GOARM=6; fi; \
    GOOS=linux \
    GOARCH=${TARGETARCH} \
    CONTAINER_BUILD=1 \
    make LINK_FLAGS="-w -s" cloudflared 

FROM scratch

ARG IMAGE_BUILD_DATE
ARG IMAGE_VCS_REF

ARG CLOUDFLARED_VERSION

ARG UID
ARG GID

# OCI labels for image metadata
LABEL description="Cloudflared Distroless Image (non official)" \
    org.opencontainers.image.created=${IMAGE_BUILD_DATE} \
    org.opencontainers.image.authors="Hantong Chen <public-service@7rs.net>" \
    org.opencontainers.image.url="https://github.com/han-rs/container-ci-cloudflared" \
    org.opencontainers.image.documentation="https://github.com/han-rs/container-ci-cloudflared/blob/main/README.md" \
    org.opencontainers.image.source="https://github.com/han-rs/container-ci-cloudflared" \
    org.opencontainers.image.version=${CLOUDFLARED_VERSION}+image.${IMAGE_VCS_REF} \
    org.opencontainers.image.vendor="Hantong Chen" \
    org.opencontainers.image.licenses="Apache-2.0" \
    org.opencontainers.image.title="Cloudflared Distroless Image (non official)" \
    org.opencontainers.image.description="Cloudflared Distroless Image (non official)"

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder --chown="${UID}:${GID}" /src/cloudflared /cloudflared

ENV NO_AUTOUPDATE=true

WORKDIR /

# Run as non-root user.
USER ${UID}:${GID}

ENTRYPOINT ["/cloudflared", "--no-autoupdate"]

CMD ["version"]

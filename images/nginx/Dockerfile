# nginxinc/nginx-unprivileged:1.26-alpine — pinned by digest for reproducibility.
# Dependabot bumps this digest; the daily scheduled rebuild + `apk upgrade` below
# pulls fresh, apk-signed Alpine security patches even when the digest is unchanged.
FROM nginxinc/nginx-unprivileged:1.31.2-alpine@sha256:a8d5564c3354241473c1e152d5dd3281ab4224edb61b23c291e0bfd9854687a1

# Pull the latest signed Alpine security patches at build time (fixes e.g. OpenSSL CVEs).
USER root
RUN apk upgrade --no-cache && rm -rf /var/cache/apk/*

COPY nginx.conf /etc/nginx/nginx.conf
COPY security-headers.conf /etc/nginx/security-headers.conf

# Drop back to the unprivileged uid that the base image ships with.
USER 101

EXPOSE 8080

# OCI provenance labels (populated from build-args in CI).
ARG IMAGE_REVISION="dev"
ARG IMAGE_CREATED="unknown"
LABEL org.opencontainers.image.title="nginx-base" \
      org.opencontainers.image.description="Hardened, non-root nginx base image for static sites in government production." \
      org.opencontainers.image.source="https://github.com/RijksICTGilde/base-images" \
      org.opencontainers.image.licenses="EUPL-1.2" \
      org.opencontainers.image.base.name="docker.io/nginxinc/nginx-unprivileged:1.26-alpine" \
      org.opencontainers.image.revision="${IMAGE_REVISION}" \
      org.opencontainers.image.created="${IMAGE_CREATED}"

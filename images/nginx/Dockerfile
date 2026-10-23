# nginxinc/nginx-unprivileged (alpine), pinned by digest for reproducible builds.
# Dependabot bumps this digest; a rebuild (dispatched by scan.yml on a fixable CVE or
# pending Alpine updates) + `apk upgrade` below pulls fresh, apk-signed Alpine security
# patches even when the digest is unchanged.
FROM nginxinc/nginx-unprivileged:1.31.6-alpine@sha256:884e0b7f42f303641b0f4e78755aea647521dca0b89ca3be7992ad78b5c07434

# Pull the latest signed Alpine security patches at build time (fixes e.g. OpenSSL CVEs).
USER root
RUN apk upgrade --no-cache && rm -rf /var/cache/apk/* \
    # Our nginx.conf includes conf.d/*.conf at http scope as an extension point;
    # the upstream default.conf (a second server on 8080) must not be there.
    && rm -f /etc/nginx/conf.d/default.conf \
    # Second extension point, for locations inside our server block. Same
    # ownership as conf.d so the upstream envsubst templates can target it too.
    && mkdir -p /etc/nginx/locations.d \
    && chown nginx:root /etc/nginx/locations.d && chmod 775 /etc/nginx/locations.d

COPY nginx.conf /etc/nginx/nginx.conf
COPY security-headers.conf /etc/nginx/security-headers.conf
COPY snippets/ /etc/nginx/snippets/

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
      org.opencontainers.image.base.name="docker.io/nginxinc/nginx-unprivileged" \
      org.opencontainers.image.revision="${IMAGE_REVISION}" \
      org.opencontainers.image.created="${IMAGE_CREATED}"

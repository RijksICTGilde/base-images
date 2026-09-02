# haproxy:3.2.19-alpine (HAProxy 3.2 LTS) — pinned by digest for reproducibility.
# Dependabot bumps this digest; the daily scheduled rebuild + `apk upgrade` below
# pulls fresh, apk-signed Alpine security patches even when the digest is unchanged.
FROM haproxy:3.4.4-alpine@sha256:c0afc4864dca9c68694cd1290433f0ee79b5c55be80f6745a165ffe373b9a564

# Pull the latest signed Alpine security patches at build time.
USER root
RUN apk upgrade --no-cache && rm -rf /var/cache/apk/*

COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg

# Unprivileged, OpenShift restricted-v2 compatible, read-only-root friendly.
USER 10001

EXPOSE 8080

ARG IMAGE_REVISION="dev"
ARG IMAGE_CREATED="unknown"
LABEL org.opencontainers.image.title="haproxy-redirect" \
      org.opencontainers.image.description="Minimal non-root HAProxy image that 302-redirects every request to \$TARGET_URL." \
      org.opencontainers.image.source="https://github.com/RijksICTGilde/base-images" \
      org.opencontainers.image.licenses="EUPL-1.2" \
      org.opencontainers.image.base.name="docker.io/library/haproxy:3.2.19-alpine" \
      org.opencontainers.image.revision="${IMAGE_REVISION}" \
      org.opencontainers.image.created="${IMAGE_CREATED}"

# haproxy (alpine), pinned by digest for reproducible builds.
# Dependabot bumps this digest; a rebuild (dispatched by scan.yml on a fixable CVE or
# pending Alpine updates) + `apk upgrade` below pulls fresh, apk-signed Alpine security
# patches even when the digest is unchanged.
FROM haproxy:3.4.7-alpine@sha256:b9fe316f718d5015c5cfebd8ca019591f3e44656f61d93cb8b59a1028961e530

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
      org.opencontainers.image.base.name="docker.io/library/haproxy" \
      org.opencontainers.image.revision="${IMAGE_REVISION}" \
      org.opencontainers.image.created="${IMAGE_CREATED}"

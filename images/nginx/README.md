# nginx-base

[![Latest version](https://ghcr-badge.egpl.dev/rijksictgilde/nginx-base/latest_tag?trim=major&label=latest)](https://github.com/RijksICTGilde/base-images/pkgs/container/nginx-base)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/RijksICTGilde/base-images/badge)](https://scorecard.dev/viewer/?uri=github.com/RijksICTGilde/base-images)

Hardened nginx base image without root for static websites in government environments, with an optional reverse proxy. Published to `ghcr.io/rijksictgilde/nginx-base` with [CalVer](https://calver.org/) versions (`YYYY.MM.PATCH`). The published image is scanned daily and rebuilt when a fix is available. Every build is signed and has an SBOM and a build-provenance attestation. See [`SECURITY.md`](../../SECURITY.md).

## Usage

Pin the base image by digest so builds are reproducible and you decide when to upgrade. Dependabot can propose the bumps. Take the current version and digest from the [package page](https://github.com/RijksICTGilde/base-images/pkgs/container/nginx-base).

```dockerfile
FROM ghcr.io/rijksictgilde/nginx-base:<version>@sha256:<digest>
COPY dist/ /usr/share/nginx/html/
```

```bash
docker build -t my-site .
docker run -p 8080:8080 my-site
```

## What is included

- **Non-root.** Runs as uid 101.
- **Read-only root filesystem.** Only `/tmp` needs to be writable. The upstream envsubst templates need a writable filesystem and do not work with `readOnlyRootFilesystem`.
- **Security headers on every response**, including cached static assets: `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Strict-Transport-Security`, a `Content-Security-Policy` with `object-src 'none'; base-uri 'self'; frame-ancestors 'self'`, `Permissions-Policy`, `Cross-Origin-Opener-Policy`, `Cross-Origin-Resource-Policy` and `X-Permitted-Cross-Domain-Policies`.
- **Static content is `GET` and `HEAD` only.** Other methods return `405`. Proxied locations set their own policy, see [Reverse proxy](#reverse-proxy).
- **Dotfiles are never served**, also under a proxied prefix. `.env` and `.git` return `404` and `.well-known` stays reachable.
- **Health endpoints** `/healthz` and `/readyz` return `200 ok`, answered by nginx itself and kept out of the access log.
- **Server version hidden** with `server_tokens off`.
- **Gzip** for text types and **one-year immutable caching** for `js`, `css`, images and fonts.
- **One worker, 1024 connections.** nginx's default `worker_processes auto` starts one worker per core of the node, and a Kubernetes CPU limit does not change that. On large nodes it caused hundreds of MB per pod and OOMKills. If you replace `nginx.conf`, keep `worker_processes` fixed.
- **Port 8080**, and no Docker `HEALTHCHECK`: use the Kubernetes probes below.

Size and memory, measured on the current build: the image is 66 MB, and `docker stats` shows about 3 MiB after 2000 requests. A resources block that fits:

```yaml
resources:
  requests: { cpu: 10m, memory: 16Mi }
  limits:   { memory: 64Mi }
```

### Health endpoints

Both endpoints return `200` with body `ok`. For a static server liveness and readiness are the same check, so each probe can use its conventional path. The endpoints are exact-match locations answered by nginx, so site content cannot shadow them.

```yaml
livenessProbe:
  httpGet: { path: /healthz, port: 8080 }
readinessProbe:
  httpGet: { path: /readyz, port: 8080 }
```

### Customising security headers

The headers live in `/etc/nginx/security-headers.conf`. To tighten the CSP, for example with `default-src 'self'`, ship your own copy:

```dockerfile
FROM ghcr.io/rijksictgilde/nginx-base:<version>@sha256:<digest>
COPY security-headers.conf /etc/nginx/security-headers.conf
COPY dist/ /usr/share/nginx/html/
```

## Reverse proxy

You can proxy part of the URL space to a backend without replacing `nginx.conf` and without losing the hardening. Two directories are included, both empty by default:

| Path | Scope | Put here |
| --- | --- | --- |
| `/etc/nginx/locations.d/*.conf` | inside the `server` block | `location` blocks: proxied prefixes and extra rules |
| `/etc/nginx/conf.d/*.conf` | `http` level | `upstream {}` blocks, `map`s, a `resolver`, `limit_req_zone`, or an extra `server {}` |

Proxy `/api/` with one file:

```nginx
# api.conf
location /api/ {
    include /etc/nginx/snippets/proxy.conf;
    proxy_pass http://backend:8080;
}
```

```dockerfile
FROM ghcr.io/rijksictgilde/nginx-base:<version>@sha256:<digest>
COPY api.conf /etc/nginx/locations.d/api.conf
COPY dist/ /usr/share/nginx/html/
```

The snippet uses HTTP/1.1 to the backend and passes `Host`, `X-Real-IP`, `X-Forwarded-For` (appended, so an ingress in front keeps the real client first), `X-Forwarded-Proto` and `X-Forwarded-Host`. It hides the backend's `X-Powered-By` and adds the security headers to proxied responses. It sets nothing else, so add per location what you need:

```nginx
location /api/ {
    include /etc/nginx/snippets/proxy.conf;
    proxy_pass http://backend:8080;
    client_max_body_size 50m;    # uploads (default 1m)
    proxy_read_timeout   300s;   # slow backends (default 60s)
    proxy_buffering      off;     # streaming and SSE
}
```

For WebSockets use `snippets/proxy-websocket.conf` instead of `proxy.conf`. It adds the `Upgrade` and `Connection` handling and a one-hour read timeout.

- **Methods.** The backend decides which methods a proxied location accepts. Static content stays `GET` and `HEAD` only.
- **Precedence.** A prefix location in `locations.d` beats `location /`, and the static-asset rules sit inside `location /`. So `/api/report.png` reaches your backend, and `/api/.env` is still `404`.
- **Headers.** When the backend sends its own `Content-Security-Policy`, the response carries both and browsers enforce both. Add `proxy_hide_header Content-Security-Policy;` to the location to drop the backend's, or ship a `security-headers.conf` without a CSP to rely on the backend's alone.
- **DNS.** A hostname in `proxy_pass` is resolved once at startup, which suits a Kubernetes Service. With a variable in `proxy_pass`, add a `resolver` in `conf.d`. Set `NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1` to have the entrypoint export the pod's nameservers as `$NGINX_LOCAL_RESOLVERS` for use in templates.
- **Templates.** Files in `/etc/nginx/templates/*.template` are rendered with envsubst at startup into `conf.d/`. Set `NGINX_ENVSUBST_OUTPUT_DIR=/etc/nginx/locations.d` to render locations instead.
- **Capacity.** A proxied request uses two connections. Raise `worker_connections` in your own `nginx.conf` only after you measure a limit.

## Local testing

```bash
./build.sh
```

The script builds the base image, asks for the path to your site files (default `./example`) and an image name, and builds your site on top. Run the result with `docker run -p 8080:8080 my-site`.

## Keeping up to date

Add [Dependabot](https://docs.github.com/en/code-security/dependabot) to your project to get a pull request when a new digest is published:

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: docker
    directory: /
    schedule:
      interval: weekly
    cooldown:
      default-days: 7
```

## CI/CD

- A daily scan checks the published image. A fixable CRITICAL or HIGH CVE starts a rebuild, and pending Alpine updates are rebuilt on Mondays.
- On every push to `main` and on every such rebuild, the pipeline runs the functional test and [Trivy](https://trivy.dev/) CVE and Dockerfile scans (results in the Security tab). Only if these pass does it push, sign with keyless cosign, and attach the SBOM and SLSA provenance.
- A CalVer git tag is created per release.
- Supply-chain hardening is described in [`SECURITY.md`](../../SECURITY.md).

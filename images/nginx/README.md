# nginx-base

[![Latest version](https://ghcr-badge.egpl.dev/rijksictgilde/nginx-base/latest_tag?trim=major&label=latest)](https://github.com/RijksICTGilde/base-images/pkgs/container/nginx-base)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/RijksICTGilde/base-images/badge)](https://scorecard.dev/viewer/?uri=github.com/RijksICTGilde/base-images)

Hardened, non-root nginx base image for serving static websites in government production environments.

Published to `ghcr.io/rijksictgilde/nginx-base` using [CalVer](https://calver.org/) (`YYYY.MM.PATCH`).
The image is **rebuilt daily** so Alpine/OpenSSL security patches land automatically, and every
image is **signed** and ships with an **SBOM** and **build-provenance** attestation. See
[`SECURITY.md`](SECURITY.md).

## Usage

Add it to your project's `Dockerfile`, **pinned by digest** — so builds are reproducible and you
control upgrades (Dependabot bumps it for you). Grab the current version and digest from the
[package page](https://github.com/RijksICTGilde/base-images/pkgs/container/nginx-base) (the badge
above always links to the latest):

```dockerfile
FROM ghcr.io/rijksictgilde/nginx-base:2026.06.1@sha256:61ac904cd9438c6db6977c1ae16a472d914902c90b99d489d0e18394c3292eeb

COPY dist/ /usr/share/nginx/html/
```

Then build and run:

```bash
docker build -t my-site .
docker run -p 8080:8080 my-site
```

## What's included

- **Non-root** — runs as uid 101, no root escalation
- **Read-only root filesystem** — only `/tmp` is writable
- **Daily security patches** — base pinned by digest + `apk upgrade` on every build
- **Security headers on every response** — `X-Content-Type-Options`, `X-Frame-Options`,
  `Referrer-Policy`, `Strict-Transport-Security`, a non-breaking `Content-Security-Policy`
  baseline, `Permissions-Policy`, `Cross-Origin-Opener-Policy`, `Cross-Origin-Resource-Policy`,
  `X-Permitted-Cross-Domain-Policies` — including on cached static assets
- **Method restriction** — static content is `GET`/`HEAD` only; everything else returns `405`
  (proxied locations set their own policy, see below)
- **Reverse proxy, opt-in** — drop one file in `/etc/nginx/locations.d/` to proxy `/api/` (or
  WebSockets) to a backend, with the hardening left intact. See [Reverse proxy](#reverse-proxy)
- **One worker, on purpose** — `worker_processes 1`. The nginx default `auto` starts one worker per
  *node* core (a CPU limit does not cap it), which on a large node means ~200 workers, hundreds of
  MB per pod and OOMKills. One worker with 1024 connections serves thousands of concurrent users.
- **Health endpoints** — `/healthz` and `/readyz` return `200 ok`, answered by nginx itself and
  kept out of the access log
- **Dotfiles not served** — `.env`, `.git`, … return `404` (`.well-known` stays reachable)
- **Server version hidden** — `server_tokens off`
- **Gzip compression** and **1-year static-asset caching**
- **Port 8080** — unprivileged port, ready for Kubernetes
- **Signed + SBOM + provenance** — see [verifying an image](SECURITY.md#verifying-an-image)

### Customising security headers

The headers live in `/etc/nginx/security-headers.conf`. To tighten the CSP (e.g. a strict
`default-src 'self'`) ship your own copy in your downstream image:

```dockerfile
FROM ghcr.io/rijksictgilde/nginx-base:2026.06.1@sha256:61ac904cd9438c6db6977c1ae16a472d914902c90b99d489d0e18394c3292eeb
COPY security-headers.conf /etc/nginx/security-headers.conf
COPY dist/ /usr/share/nginx/html/
```

## Reverse proxy

The image serves static files by default, but you can proxy part of the URL space to a backend
without replacing `nginx.conf` (and without losing the hardening). Two extension points are
included:

| Path | Scope | Put here |
| --- | --- | --- |
| `/etc/nginx/locations.d/*.conf` | inside the `server` block | `location` blocks: proxied prefixes, extra rules |
| `/etc/nginx/conf.d/*.conf` | `http` level | `upstream {}` blocks, `map`s, a `resolver`, `limit_req_zone`, or an extra `server {}` |

Proxy `/api/` to a backend with one file:

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

What the snippet does: HTTP/1.1 to the backend, passes `Host`, `X-Real-IP`, `X-Forwarded-For`
(appended, so an ingress in front keeps the real client first), `X-Forwarded-Proto` and
`X-Forwarded-Host`, hides the backend's `X-Powered-By`, and re-applies the security headers on
proxied responses. It deliberately sets nothing else, so add per location what you need:

```nginx
location /api/ {
    include /etc/nginx/snippets/proxy.conf;
    proxy_pass http://backend:8080;
    client_max_body_size 50m;    # uploads (default 1m)
    proxy_read_timeout   300s;   # slow backends (default 60s)
    proxy_buffering      off;    # streaming / SSE
}
```

For WebSockets use `snippets/proxy-websocket.conf` *instead of* `proxy.conf` (it adds the
`Upgrade`/`Connection` handling and a long read timeout).

Good to know:

- **Methods.** Proxied locations are not restricted to `GET`/`HEAD`; the backend decides. Static
  content under `location /` stays `GET`/`HEAD` only.
- **Precedence.** A prefix location in `locations.d` beats `location /`, and the static-asset
  caching rules are nested inside `location /`, so `/api/report.png` reaches your backend instead
  of a `404` from disk. Dotfiles are blocked everywhere, so `/api/.env` is still `404`.
- **Headers.** If the backend sends its own `Content-Security-Policy`, browsers enforce both. Ship
  your own `/etc/nginx/security-headers.conf` without a CSP to let the backend's rule alone, or
  add `proxy_hide_header Content-Security-Policy;` to the location to drop the backend's.
- **DNS.** A hostname in `proxy_pass` is resolved once at startup, which is fine for a Kubernetes
  Service. If you use a variable in `proxy_pass`, add a `resolver` in `conf.d` (the upstream
  entrypoint exports the pod's resolvers as `$NGINX_LOCAL_RESOLVERS` for use in templates).
- **Templates.** The upstream image's envsubst templates still work: files in
  `/etc/nginx/templates/*.template` are rendered into `conf.d/` at startup (set
  `NGINX_ENVSUBST_OUTPUT_DIR=/etc/nginx/locations.d` to render locations instead). This needs a
  writable filesystem, so it does not combine with `readOnlyRootFilesystem`.
- **Capacity.** One worker with 1024 connections; a proxied request uses two. Raise
  `worker_connections` in your own `nginx.conf` only if you really measure a limit.

## Lean & low-footprint

Small, lean, and built for real traffic:

- **~52 MB image, ~2–5 MB RAM** — pack pods densely and set tiny resource limits.
- **Serves thousands of concurrent users** on the default settings
- **Memory stays flat under load** — files are streamed straight from disk

Example resources block:

```yaml
resources:
  requests: { cpu: 10m, memory: 16Mi }
  limits:   { memory: 64Mi }
```

## Local testing

To quickly test with a local site:

```bash
./build.sh
```

It builds the base image locally, then asks for the path to your site files (defaults to
`./example`) and an image name. Run the result with `docker run -p 8080:8080 my-site`.

## Keeping up to date

Add [Dependabot](https://docs.github.com/en/code-security/dependabot) to your project to get
automatic PRs when a new digest is published:

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

- **Daily** (and on every push to `main`): rebuild, run security tests + [Trivy](https://trivy.dev/)
  CVE and Dockerfile-misconfiguration scanning (results in the **Security** tab), and — only if the
  scan passes — build, push, **sign** (keyless cosign), and attach **SBOM** + **SLSA provenance**.
- A matching CalVer git tag is created per release.
- Dependency and supply-chain hardening is documented in [`SECURITY.md`](SECURITY.md).

## Cluster compatibility

- Non-root (uid 101)
- Read-only root filesystem (writable `/tmp` only)
- Listens on port 8080
- Minimal footprint: 1 worker (pinned), 1024 connections
- No Docker `HEALTHCHECK` — use Kubernetes liveness/readiness probes against the endpoints below

### Health endpoints

`/healthz` (liveness) and `/readyz` (readiness) both return `200` with an `ok` body, following the
Kubernetes naming convention. For a static file server the two checks are equivalent, so both are
provided purely so each probe can use its conventional path.

They are answered by nginx itself rather than read from the docroot, so a probe stays green
regardless of what your image copies in, and they are excluded from the access log — probe traffic
fires every few seconds forever and says nothing about real visitors. Both are exact-match
locations, so site content can never shadow them.

```yaml
livenessProbe:
  httpGet: { path: /healthz, port: 8080 }
readinessProbe:
  httpGet: { path: /readyz, port: 8080 }
```


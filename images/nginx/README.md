# nginx-base

[![Latest version](https://ghcr-badge.egpl.dev/rijksictgilde/nginx-base/latest_tag?trim=major&label=latest)](https://github.com/RijksICTGilde/base-images/pkgs/container/nginx-base)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/RijksICTGilde/base-images/badge)](https://scorecard.dev/viewer/?uri=github.com/RijksICTGilde/base-images)

Hardened, non-root nginx image for static websites, with an optional reverse proxy. Published to `ghcr.io/rijksictgilde/nginx-base` with [CalVer](https://calver.org/) versions. Signed, with an SBOM and a build-provenance attestation. See [`SECURITY.md`](../../SECURITY.md) and the [comparison with upstream](../../README.md#why-our-own-base-images).

## Usage

Copy your built site into the image. No nginx configuration is needed.

```dockerfile
FROM ghcr.io/rijksictgilde/nginx-base:<version>@sha256:<digest>
COPY dist/ /usr/share/nginx/html/
```

```bash
docker build -t my-site .
docker run -p 8080:8080 my-site
```

Pin by digest and let Dependabot propose bumps. The current version and digest are on the [package page](https://github.com/RijksICTGilde/base-images/pkgs/container/nginx-base).

**Error pages.** A `404.html` and a `50x.html` in your folder are used, with the right status. `50x.html` answers `500`, `502`, `503` and `504`, including a proxied backend that is down. Without them nginx shows its built-in pages.

**Single-page apps.** A path that is not a file returns `404`, so a client-side route fails on a deep link. Add `error_page 404 =200 /index.html;` in a file under `/etc/nginx/locations.d/`. Every missing path, including a missing asset, then returns `index.html` with `200`. Real files and `/healthz` are not affected.

## What is included

- **Non-root.** uid 101. Only `/tmp` needs to be writable, so `readOnlyRootFilesystem` works. The upstream envsubst templates need a writable filesystem.
- **Security headers on every response**, also on cached assets: `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Strict-Transport-Security`, `Content-Security-Policy` (`object-src 'none'; base-uri 'self'; frame-ancestors 'self'`), `Permissions-Policy`, `Cross-Origin-Opener-Policy`, `Cross-Origin-Resource-Policy`, `X-Permitted-Cross-Domain-Policies`.
- **Static content is `GET` and `HEAD` only.** Other methods return `405`. Proxied locations set their own policy.
- **Dotfiles are never served**, also under a proxied prefix. `.well-known` stays reachable.
- **`/healthz` and `/readyz`** return `200 ok`, answered by nginx and kept out of the access log. Liveness and readiness are the same check for a static server.
- **Version hidden** (`server_tokens off`), **gzip** for text types, and **one-year immutable caching** for `js`, `css`, images and fonts.
- **One worker, 1024 connections.** `worker_processes auto` starts one worker per core of the node, which caused OOMKills on large nodes. If you replace `nginx.conf`, keep `worker_processes` fixed.
- **Port 8080.** No Docker `HEALTHCHECK`: use the Kubernetes probes.

The image is 66 MB and uses about 3 MiB in `docker stats` after 2000 requests.

```yaml
resources:
  requests: { cpu: 10m, memory: 16Mi }
  limits:   { memory: 64Mi }
livenessProbe:
  httpGet: { path: /healthz, port: 8080 }
readinessProbe:
  httpGet: { path: /readyz, port: 8080 }
```

To change the headers, for example a stricter CSP, ship your own `/etc/nginx/security-headers.conf`.

## Reverse proxy

Proxy part of the URL space without replacing `nginx.conf`. Both directories are empty by default:

| Path | Scope | Put here |
| --- | --- | --- |
| `/etc/nginx/locations.d/*.conf` | inside the `server` block | `location` blocks |
| `/etc/nginx/conf.d/*.conf` | `http` level | `upstream {}`, `map`, `resolver`, `limit_req_zone`, an extra `server {}` |

```nginx
# api.conf
location /api/ {
    include /etc/nginx/snippets/proxy.conf;
    proxy_pass http://backend:8080;
    client_max_body_size 50m;    # uploads (default 1m)
    proxy_read_timeout   300s;   # slow backends (default 60s)
}
```

```dockerfile
COPY api.conf /etc/nginx/locations.d/api.conf
```

The snippet uses HTTP/1.1 to the backend and passes `Host`, `X-Real-IP`, `X-Forwarded-For` (appended, so an ingress in front keeps the real client first), `X-Forwarded-Proto` and `X-Forwarded-Host`. It hides the backend's `X-Powered-By` and adds the security headers. For WebSockets use `snippets/proxy-websocket.conf` instead. It adds the `Upgrade` handling and a one-hour read timeout.

- **Methods.** The backend decides. Static content stays `GET` and `HEAD` only.
- **Precedence.** A prefix in `locations.d` beats `location /`, so `/api/report.png` reaches your backend. `/api/.env` is still `404`.
- **CSP.** If the backend also sends a `Content-Security-Policy`, the response has both and browsers enforce both. Add `proxy_hide_header Content-Security-Policy;` to drop the backend's.
- **DNS.** A hostname in `proxy_pass` is resolved at startup, which suits a Kubernetes Service. With a variable, add a `resolver` in `conf.d`. `NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1` exports the pod's nameservers as `$NGINX_LOCAL_RESOLVERS` for templates.
- **Templates.** Files in `/etc/nginx/templates/*.template` are rendered with envsubst into `conf.d/`. Set `NGINX_ENVSUBST_OUTPUT_DIR=/etc/nginx/locations.d` to render locations.
- **Capacity.** A proxied request uses two connections. Raise `worker_connections` in your own `nginx.conf` only after you measure a limit.

## Local testing

`./build.sh` builds the base image, asks for the path to your site (default `./example`) and an image name, and builds your site on top.

# nginx-base

[![Latest version](https://ghcr-badge.egpl.dev/rijksictgilde/nginx-base/latest_tag?trim=major&label=latest)](https://github.com/RijksICTGilde/nginx-base/pkgs/container/nginx-base)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/RijksICTGilde/nginx-base/badge)](https://scorecard.dev/viewer/?uri=github.com/RijksICTGilde/nginx-base)

Hardened, non-root nginx base image for serving static websites in government production environments.

Published to `ghcr.io/rijksictgilde/nginx-base` using [CalVer](https://calver.org/) (`YYYY.MM.PATCH`).
The image is **rebuilt daily** so Alpine/OpenSSL security patches land automatically, and every
image is **signed** and ships with an **SBOM** and **build-provenance** attestation. See
[`SECURITY.md`](SECURITY.md).

## Usage

In your project's `Dockerfile`:

```dockerfile
FROM ghcr.io/rijksictgilde/nginx-base:latest

COPY dist/ /usr/share/nginx/html/
```

**For production, pin by digest** so your build is reproducible and Dependabot bumps it for you:

```dockerfile
FROM ghcr.io/rijksictgilde/nginx-base:2026.06.0@sha256:<digest>

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
- **Method restriction** — only `GET`/`HEAD`; everything else returns `405`
- **Dotfiles not served** — `.env`, `.git`, … return `404` (`.well-known` stays reachable)
- **Server version hidden** — `server_tokens off`
- **Gzip compression** and **1-year static-asset caching**
- **Port 8080** — unprivileged port, ready for Kubernetes
- **Signed + SBOM + provenance** — see [verifying an image](SECURITY.md#verifying-an-image)

### Customising security headers

The headers live in `/etc/nginx/security-headers.conf`. To tighten the CSP (e.g. a strict
`default-src 'self'`) ship your own copy in your downstream image:

```dockerfile
FROM ghcr.io/rijksictgilde/nginx-base:latest
COPY security-headers.conf /etc/nginx/security-headers.conf
COPY dist/ /usr/share/nginx/html/
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
- Minimal footprint: 1 worker, 128 connections
- No `HEALTHCHECK` — use Kubernetes liveness/readiness probes instead

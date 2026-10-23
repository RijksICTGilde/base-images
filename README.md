# base-images

**Lean, mean, security-clean production machines.**

[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/RijksICTGilde/base-images/badge)](https://scorecard.dev/viewer/?uri=github.com/RijksICTGilde/base-images)

A small collection of hardened, non-root container images for government environments. Every image runs as an unprivileged user, is scanned, signed with keyless cosign, and ships with an SBOM and a build-provenance attestation. Published images are scanned daily and rebuilt only when there is a reason: a fixable CVE, pending Alpine updates (batched weekly), a new upstream version, or a change in this repository. See [`SECURITY.md`](SECURITY.md).

## Why our own base images

Your site is a folder: copy it into the nginx image with a two-line Dockerfile and it runs, with no nginx configuration. See [Usage](images/nginx/README.md#usage).

The upstream images are written for a single host. On a Kubernetes node with many cores they behave differently, and their defaults leave out settings a government site needs. These images change those defaults and nothing else. The numbers below were measured on the current builds against the upstream image each one is based on.

**Memory on large nodes.** nginx starts one worker per core of the node (`worker_processes auto`), and HAProxy starts one thread per core. A Kubernetes CPU limit changes neither. Our images fix one worker and one thread. Idle memory in `docker stats`:

| Cores of the node | nginx upstream | nginx-base | HAProxy official | haproxy-redirect |
| --- | --- | --- | --- | --- |
| 14 | 11 MiB | 3 MiB | 89 MiB | 16 MiB |
| 120 | 80 MiB | 3 MiB | 149 MiB | 16 MiB |
| 192 | 128 MiB | 3 MiB | 190 MiB | 16 MiB |

The HAProxy rows combine two defaults. Without `maxconn` HAProxy sizes for the file-descriptor limit, which costs about 64 MiB (80 MiB against 16 MiB at one thread). Each extra thread then costs about 0.6 MiB. Our configuration sets `maxconn 256`, so a pod accepts at most 256 concurrent connections.

**Defaults of nginx**, measured on a running site with a `.env` file and a CSS file:

| | nginx upstream | nginx-base |
| --- | --- | --- |
| Security headers sent | 0 | 9 |
| `Server` header | `nginx/1.31.6` | `nginx` |
| `GET /.env` | 200, file served | 404 |
| Static assets | no `Cache-Control`, no gzip | one year, immutable, gzip |
| `GET /healthz` | 404 | 200 |
| Reverse proxy | replace the config | one file in `locations.d`, tested for `POST` and forwarded headers |

**Defaults of HAProxy.** The official image has no configuration and needs one mounted. `haproxy-redirect` runs with only `TARGET_URL` set, logs to stdout and keeps health probes out of the log.

**What it costs.** The images are larger than their base, because of the `apk upgrade` layer: nginx 66.3 MB against 60.6 MB, HAProxy 52.5 MB against 44.3 MB.

How we measured: the 14-core row ran on a 14-core machine. The 120 and 192 rows started the upstream image with the worker or thread count that `auto` picks on a node of that size, idle, and did not run on such a node. The HAProxy rows use our redirect configuration with only `nbthread` and `maxconn` varied.

## Images

| Image | What it does | Pull |
| --- | --- | --- |
| [**nginx**](images/nginx/) | Base for static sites. Optionally a reverse proxy (`/api/` to a backend, WebSockets) with one extra file. Security headers, dotfiles blocked, one fixed worker. | `ghcr.io/rijksictgilde/nginx-base` |
| [**haproxy-redirect**](images/haproxy-redirect/) | Redirects every request with a `302` to `$TARGET_URL`, keeping path and query. | `ghcr.io/rijksictgilde/haproxy-redirect` |

Pin by digest in production and let Dependabot propose bumps. The current version and digest are on the [packages page](https://github.com/orgs/RijksICTGilde/packages?repo_name=nginx-base).

```dockerfile
# nginx: build your static site on top
FROM ghcr.io/rijksictgilde/nginx-base:<version>@sha256:<digest>
COPY dist/ /usr/share/nginx/html/
```

```yaml
# haproxy-redirect: run as is and give it a target
env:
  - name: TARGET_URL
    value: https://new-host.example.com
```

## Repository layout

```
images/<name>/        Dockerfile, config, README, test.sh  (one folder per image)
.github/workflows/
  reusable-image.yml   build → apk upgrade → Trivy gate → test.sh → push by digest → sign → attest → promote
  build-verify.yml     matrix over images, on every PR and push (verify only)
  publish.yml          matrix over images, on push to main and on dispatch (publish)
  scan.yml             daily scan of the published images, dispatches publish.yml when needed
  cleanup.yml          removes untagged and orphaned manifests
  scorecard.yml · dependabot-auto-merge.yml
```

## Adding a new image

1. Create `images/<name>/` with a `Dockerfile`, its config, a `README.md`, and a `test.sh` that takes the image reference as `$1` and exits non-zero on failure.
2. Add one entry to [`images.json`](images.json) (name, context, image). It feeds the build matrix and the daily scan.
3. Add the image directory under `docker` in `.github/dependabot.yml` and the package name in `cleanup.yml`.

No new repository, secrets or ruleset are needed: `reusable-image.yml` applies the same build, scan, sign and publish steps to every image. A push or PR builds only the changed images.

## Local development

```bash
task build -- nginx                 # build one image
task test  -- haproxy-redirect      # build and run its functional test
task scan  -- nginx                 # Trivy CVE and Dockerfile scan
task test-all                       # test every image
```

## Versions and retention

Each image has a CalVer version (`YYYY.MM.PATCH`), git-tagged as `<name>/YYYY.MM.PATCH`. Tagged versions are never deleted. Only untagged and orphaned manifests are cleaned up daily. Signatures and attestations of tagged versions stay.

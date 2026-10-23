# base-images

**Lean, mean, security-clean production machines.**

[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/RijksICTGilde/base-images/badge)](https://scorecard.dev/viewer/?uri=github.com/RijksICTGilde/base-images)

Hardened, non-root container images for government environments. Every image is scanned, signed with keyless cosign, and ships with an SBOM and a build-provenance attestation. Images are scanned daily and rebuilt only when there is a reason: a fixable CVE, pending Alpine updates (batched weekly), a new upstream version, or a change here. See [`SECURITY.md`](SECURITY.md).

| Image | What it does | Pull |
| --- | --- | --- |
| [**nginx**](images/nginx/) | Static sites, with an optional reverse proxy (`/api/` to a backend, WebSockets) from one extra file. | `ghcr.io/rijksictgilde/nginx-base` |
| [**haproxy-redirect**](images/haproxy-redirect/) | Redirects every request with a `302` to `$TARGET_URL`, keeping path and query. | `ghcr.io/rijksictgilde/haproxy-redirect` |

Your site is a folder. Pin the image by digest (the current one is on the [packages page](https://github.com/orgs/RijksICTGilde/packages?repo_name=nginx-base)) and copy the folder in. No nginx configuration is needed.

```dockerfile
FROM ghcr.io/rijksictgilde/nginx-base:<version>@sha256:<digest>
COPY dist/ /usr/share/nginx/html/
```

```yaml
# haproxy-redirect: run as is and give it a target
env:
  - name: TARGET_URL
    value: https://new-host.example.com
```

## Why our own base images

The upstream images are written for a single host. On a node with many cores they use far more memory, and their defaults leave out settings a government site needs. Measured on the current builds against the upstream image each is based on:

**Memory on large nodes.** nginx starts one worker per core of the node (`worker_processes auto`) and HAProxy one thread per core. A Kubernetes CPU limit changes neither. Ours use one worker and one thread. Idle memory in `docker stats`:

| Cores of the node | nginx upstream | nginx-base | HAProxy official | haproxy-redirect |
| --- | --- | --- | --- | --- |
| 14 | 11 MiB | 3 MiB | 89 MiB | 16 MiB |
| 120 | 80 MiB | 3 MiB | 149 MiB | 16 MiB |
| 192 | 128 MiB | 3 MiB | 190 MiB | 16 MiB |

HAProxy without `maxconn` sizes for the file-descriptor limit, which costs about 64 MiB. Each extra thread costs about 0.6 MiB. We set `maxconn 256`, so a pod accepts at most 256 concurrent connections.

**nginx defaults**, on a running site with a `.env` file and a CSS file:

| | nginx upstream | nginx-base |
| --- | --- | --- |
| Security headers sent | 0 | 9 |
| `Server` header | `nginx/1.31.6` | `nginx` |
| `GET /.env` | 200, file served | 404 |
| Static assets | no `Cache-Control`, no gzip | one year, immutable, gzip |
| `GET /healthz` | 404 | 200 |
| Reverse proxy | replace the config | one file in `locations.d` |

**HAProxy defaults.** The official image needs a mounted configuration. `haproxy-redirect` runs with only `TARGET_URL` set.

**Cost.** Our images are larger because of the `apk upgrade` layer: nginx 66.3 MB against 60.6 MB, HAProxy 52.5 MB against 44.3 MB.

The 14-core row ran on a 14-core machine. The 120 and 192 rows started the upstream image with the worker or thread count `auto` picks on such a node, idle, and did not run on one. The HAProxy rows use our configuration with only `nbthread` and `maxconn` varied.

## Repository layout

```
images/<name>/        Dockerfile, config, README, test.sh  (one folder per image)
.github/workflows/
  reusable-image.yml   build → apk upgrade → Trivy gate → test.sh → push by digest → sign → attest → promote
  build-verify.yml     on every PR and push: build and test only
  publish.yml          on push to main and on dispatch: publish
  scan.yml             daily scan of published images, dispatches publish.yml when needed
  cleanup.yml          removes untagged and orphaned manifests
  scorecard.yml · dependabot-auto-merge.yml
```

## Adding an image

1. Create `images/<name>/` with a `Dockerfile`, its config, a `README.md`, and a `test.sh` that takes the image reference as `$1` and exits non-zero on failure.
2. Add an entry to [`images.json`](images.json). It feeds the build matrix and the daily scan.
3. Add the directory under `docker` in `.github/dependabot.yml` and the package name in `cleanup.yml`.

The build, scan, sign and publish steps then apply automatically.

## Local development

```bash
task build -- nginx                 # build one image
task test  -- haproxy-redirect      # build and run its functional test
task scan  -- nginx                 # Trivy CVE and Dockerfile scan
task test-all                       # test every image
```

## Versions

CalVer per image (`YYYY.MM.PATCH`), git-tagged as `<name>/YYYY.MM.PATCH`. Tagged versions are never deleted. Only untagged and orphaned manifests are cleaned up.

# base-images

[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/RijksICTGilde/base-images/badge)](https://scorecard.dev/viewer/?uri=github.com/RijksICTGilde/base-images)

A small collection of hardened, non-root container images for government environments. Every image runs as an unprivileged user, is scanned, signed with keyless cosign, and ships with an SBOM and a build-provenance attestation. Published images are scanned daily and rebuilt only when there is a reason: a fixable CVE, pending Alpine updates (batched weekly), a new upstream version, or a change in this repository. See [`SECURITY.md`](SECURITY.md).

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

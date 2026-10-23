# base-images

[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/RijksICTGilde/base-images/badge)](https://scorecard.dev/viewer/?uri=github.com/RijksICTGilde/base-images)

A small collection of **hardened, non-root container images** for government production
environments. Published images are **scanned daily** and **rebuilt when there is a reason**: a
fixable CVE, pending Alpine package updates (batched weekly), a new upstream version, or a change
here. Every build is **signed** (keyless cosign) and ships with an **SBOM** and
**build-provenance** attestation. See [`SECURITY.md`](SECURITY.md).

## Images

| Image | What it does | Pull |
| --- | --- | --- |
| [**nginx**](images/nginx/) | Hardened nginx base for static sites, with an opt-in reverse proxy (`/api/` → backend, WebSockets) via one drop-in file. Security headers, dotfiles blocked, one pinned worker. | `ghcr.io/rijksictgilde/nginx-base` |
| [**haproxy-redirect**](images/haproxy-redirect/) | Ready-to-run pod that `302`-redirects **every** request to `$TARGET_URL` (path + query preserved). Set the env var; that's all it does. | `ghcr.io/rijksictgilde/haproxy-redirect` |

Each image's own README has the full usage and options. Pin by digest in production and let
Dependabot bump it; find the current version + digest on the
[packages page](https://github.com/orgs/RijksICTGilde/packages?repo_name=nginx-base).

Quick examples:

```dockerfile
# nginx: build your static site on top
FROM ghcr.io/rijksictgilde/nginx-base:<version>@sha256:<digest>
COPY dist/ /usr/share/nginx/html/
```

```yaml
# haproxy-redirect: deploy as-is, just give it a target
env:
  - name: TARGET_URL
    value: https://new-host.example.com
```

## Repository layout

```
images/<name>/        Dockerfile, config, README, test.sh  (one folder per image)
.github/workflows/
  reusable-image.yml   build → apk upgrade → Trivy gate → test.sh → push-by-digest → sign → attest → promote
  build-verify.yml     matrix over images, runs on every PR/push (verify only)
  publish.yml          matrix over images, on push to main + on dispatch (publish)
  scan.yml             daily scan of published images; dispatches publish.yml when needed
  scorecard.yml · cleanup.yml · dependabot-auto-merge.yml
```

## Adding a new image

1. Create `images/<name>/` with a `Dockerfile`, its config, a `README.md`, and a `test.sh`
   (takes the image ref as `$1`, asserts it works, exits non-zero on failure).
2. Add one entry to [`images.json`](images.json) (name, context, image) — the single source of
   truth for the build matrix.
3. Add the image dir under `docker` in `.github/dependabot.yml` and the package name in
   `cleanup.yml`.

No new repo, secrets, or ruleset needed — the hardened build/scan/sign/publish logic in
`reusable-image.yml` applies to every image automatically. Only changed images are built on
push/PR; `scan.yml` watches the published images and rebuilds one when it needs a patch.

## Local development

```bash
task build -- nginx                 # build one image
task test  -- haproxy-redirect      # build + run its functional test
task scan  -- nginx                 # Trivy CVE + Dockerfile-misconfig scan
task test-all                       # test every image
```

## Versioning & retention

CalVer per image (`YYYY.MM.PATCH`), git-tagged as `<name>/YYYY.MM.PATCH`. Old image versions
are pruned daily (older than 180 days, keeping the 12 newest tagged + `latest`); signatures and
attestations of retained images are preserved.

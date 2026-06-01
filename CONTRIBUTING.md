# Contributing to nginx-base

Thanks for helping keep this base image secure and minimal. It is intentionally
small — the bar for adding anything is high.

## Principles

- **Minimal surface.** Every package, header, or build step is attack surface.
  Prefer removing over adding.
- **Secure by default, non-breaking.** Defaults must harden without breaking
  typical static sites (e.g. the CSP baseline avoids `default-src`).
- **Reproducible & verifiable.** Pin everything by digest/SHA; keep images signed
  with an SBOM and provenance.

## Development

```bash
# Build and smoke-test locally
docker build -t nginx-base .
./build.sh                      # interactive: build a test site on top

# Scan exactly like CI
trivy image --severity CRITICAL,HIGH --ignore-unfixed nginx-base
trivy config Dockerfile
```

Run the same functional checks CI runs: non-root uid, `nginx -t`, security headers
on `/` **and** a static asset, `POST` → `405`, dotfiles → `404`, version hidden.

## Pull requests

- Branch from `main`; keep PRs focused. CI (`Build and Verify`) must be green.
- **Pin any new GitHub Action by full commit SHA** with a `# vX.Y.Z` comment —
  never a floating tag. See [`SECURITY.md`](SECURITY.md) for why.
- Update `README.md` / `SECURITY.md` when behaviour changes.
- Dependency bumps are handled by Dependabot (patch/minor auto-merge after a 7-day
  cooldown); you normally don't need to bump versions by hand.

## Reporting security issues

Do **not** open a public issue. Use a private
[Security Advisory](https://github.com/RijksICTGilde/nginx-base/security/advisories/new).

## License

By contributing you agree that your contributions are licensed under the
[EUPL-1.2](LICENSE).

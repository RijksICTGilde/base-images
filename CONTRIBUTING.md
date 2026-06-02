# Contributing to base-images

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

Each image lives in `images/<name>/`. Build, test, and scan it the same way CI does:

```bash
task build -- nginx                 # build one image
task test  -- haproxy-redirect      # build + run its functional test (test.sh)
task scan  -- nginx                 # Trivy CVE + Dockerfile-misconfig scan
task test-all                       # test every image
```

Every image ships a `test.sh` (takes the image ref as `$1`, asserts it actually works,
exits non-zero on failure) — CI runs exactly these. To add a new image, see
"Adding a new image" in the README.

## Pull requests

- Branch from `main`; keep PRs focused. CI (`Build and Verify`) must be green.
- **Pin any new GitHub Action by full commit SHA** with a `# vX.Y.Z` comment —
  never a floating tag. See [`SECURITY.md`](SECURITY.md) for why.
- Update `README.md` / `SECURITY.md` when behaviour changes.
- Dependency bumps are handled by Dependabot (patch/minor auto-merge after a 7-day
  cooldown); you normally don't need to bump versions by hand.

## Reporting security issues

Do **not** open a public issue. Use a private
[Security Advisory](https://github.com/RijksICTGilde/base-images/security/advisories/new).

## License

By contributing you agree that your contributions are licensed under the
[EUPL-1.2](LICENSE).

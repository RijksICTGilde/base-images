# Security Policy

`nginx-base` is a hardened, non-root nginx base image for serving static sites in
government production environments. Security is the whole point of this image, so
this document describes how it stays patched, how it defends against supply-chain
attacks, and how to verify and report issues.

## Reporting a vulnerability

Please report security issues privately via [GitHub Security Advisories]
(https://github.com/RijksICTGilde/base-images/security/advisories/new) rather than
a public issue. We aim to acknowledge within 2 business days.

## Supported tags

- `latest` — the most recent successful daily build. Convenient for tracking, but
  **pin by digest in production** (see below).
- `YYYY.MM.PATCH` ([CalVer](https://calver.org/)) — immutable release tags. A new
  patch is published on every (daily) rebuild.

### Retention

Because images are rebuilt nightly and old images carry known CVEs, versions are
pruned daily: anything **older than 30 days is deleted**, but the **15 newest
tagged versions and `latest` are always kept**. Pin a recent digest and bump it
regularly (Dependabot does this for you) — do not rely on a months-old version
staying pullable. Signatures, SBOMs, and provenance attestations of retained
images are preserved.

## How patching works — two independent layers

**Layer A — OS packages (Alpine, OpenSSL): automatic, daily, no human action.**
A scheduled workflow rebuilds the image every night. The build runs `apk upgrade`,
pulling fresh Alpine packages that `apk` verifies against built-in Alpine signing
keys. This is what keeps `libssl3`/`libcrypto3` and friends current without anyone
merging anything. Vulnerable builds never ship: a Trivy `CRITICAL,HIGH` scan gates
the publish step.

**Layer B — build tooling (GitHub Actions, base-image digest): Dependabot.**
These change rarely and are the real supply-chain-attack surface, so they are
handled deliberately — see below.

## Defending against compromised supply-chain updates

A malicious *update* (e.g. a hijacked GitHub Action) is a different threat from a
stale image. Our layered defense:

1. **Full commit-SHA pinning** — every Action and the base image are pinned by
   immutable digest/SHA, defeating tag-rewriting attacks. (SHA pinning alone is
   necessary but not sufficient — hence the layers below.)
2. **Dependabot cooldown (7 days)** — only releases that have been public for a
   week are proposed, so freshly-compromised versions are filtered out by the time
   they reach us (such compromises are typically detected within hours).
3. **Selective auto-merge** — only `patch`/`minor` bumps auto-merge, and only after
   required CI checks pass. `major` bumps require human review.
4. **Egress-filtered runners** — `step-security/harden-runner` constrains outbound
   network traffic, a runtime backstop against secret exfiltration.
5. **Least-privilege tokens + keyless signing** — `GITHUB_TOKEN` defaults to
   read-only and is raised per-job; image signing uses keyless OIDC, so there is no
   long-lived signing key to steal.

### Required repository settings

For the auto-merge / least-privilege model to hold, the repository owner must:

- Enable **branch protection** on `main` with **required status checks**
  (the `Build and Verify` job) and required review for `major` bumps.
- Enable **"Allow auto-merge"** in repository settings.
- Disable force-pushes to `main`.

## Verifying an image

Every published image is signed (keyless cosign) and carries an SBOM and SLSA
build-provenance attestation.

```bash
IMAGE=ghcr.io/rijksictgilde/nginx-base:<tag>

# 1. Verify the keyless signature
cosign verify "$IMAGE" \
  --certificate-identity-regexp '^https://github.com/RijksICTGilde/base-images/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

# 2. Verify GitHub-native build provenance
gh attestation verify "oci://$IMAGE" --owner RijksICTGilde

# 3. Inspect the SBOM / provenance attestations attached in the registry
cosign download sbom "$IMAGE"
cosign verify-attestation "$IMAGE" --type slsaprovenance \
  --certificate-identity-regexp '^https://github.com/RijksICTGilde/base-images/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Hardening summary

- Non-root (uid 101), read-only-root-filesystem compatible (writable `/tmp` only)
- Base image pinned by digest; `apk upgrade` on every build
- Security headers on **every** response (incl. cached static assets)
- HTTP methods restricted to `GET`/`HEAD`; dotfiles not served; version hidden
- Trivy CVE + Dockerfile-misconfiguration scanning (results in the Security tab)
- OpenSSF Scorecard analysis

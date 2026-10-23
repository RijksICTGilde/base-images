# Security Policy

This repository publishes hardened, non-root images for government environments: `nginx-base` and `haproxy-redirect`. This document describes how they stay patched, how the build defends against supply-chain attacks, and how to verify an image and report an issue.

## Reporting a vulnerability

Report security issues privately through [GitHub Security Advisories](https://github.com/RijksICTGilde/base-images/security/advisories/new) instead of a public issue. We aim to acknowledge within 2 business days.

## Supported tags

- `latest` is the most recent successful build. Convenient for tracking, but pin by digest in production (see below).
- `YYYY.MM.PATCH` ([CalVer](https://calver.org/)) tags are immutable. A new patch is published on every build, and every build has a reason (see below), so a new version always means something changed.

### Retention

Tagged versions are never deleted, so a digest you pinned stays pullable. Whether an older version is still acceptable to run is your decision. The daily scan reports which published versions have open CVEs, and Dependabot offers you the bump. Builds are event-driven, so the catalogue grows by a few versions per month. A daily job removes only untagged manifests, orphaned referrers and ghost indexes that nothing references. Signatures, SBOMs and provenance attestations of tagged versions are kept.

## How patching works

Two layers patch independently.

**Layer A: OS packages (Alpine, OpenSSL), automatic and on demand.** A daily workflow (`scan.yml`) scans the published `latest` of each image without building. A CRITICAL or HIGH CVE with an available fix starts a rebuild the same day. Pending Alpine updates without a CVE are rebuilt in a weekly batch on Monday. The rebuild runs `apk upgrade`, which verifies packages against the Alpine signing keys, and a Trivy CRITICAL and HIGH scan gates the publish step. CVEs without a fix cannot be built away. The scan lists them, including MEDIUM, in its job summary so they get an explicit risk assessment.

**Layer B: build tooling (GitHub Actions, base-image digest), through Dependabot.** These change rarely and are the main supply-chain attack surface, so they are handled as described below.

## Defending against compromised supply-chain updates

A malicious update, such as a hijacked GitHub Action, is a different threat from a stale image. The build uses these layers:

1. **Commit-SHA pinning.** Every Action and base image is pinned by immutable digest or SHA, which defeats tag rewriting. Pinning alone is not enough, hence the layers below.
2. **Dependabot cooldown of 7 days.** Only releases that have been public for a week are proposed, so most compromised releases are caught before they reach us.
3. **Selective auto-merge.** Only patch and minor Dependabot bumps are auto-merged, and only after the required check passes. Major bumps are not auto-merged.
4. **Egress-filtered runners.** `step-security/harden-runner` limits outbound network traffic as a runtime backstop against secret exfiltration.
5. **Least-privilege tokens and keyless signing.** `GITHUB_TOKEN` is read-only by default and raised per job. Images are signed with keyless OIDC, so no long-lived signing key exists.

### Repository settings

The `keep-main-safe` ruleset on `main` requires a pull request and the `build-and-verify` check, and blocks force-push and deletion. It does not require an approving review. Auto-merge must be enabled in the repository settings for the Dependabot flow.

## Verifying an image

Every published image is signed with keyless cosign and carries an SBOM and a SLSA build-provenance attestation.

```bash
IMAGE=ghcr.io/rijksictgilde/nginx-base:<tag>   # or ghcr.io/rijksictgilde/haproxy-redirect:<tag>

# 1. Verify the keyless signature
cosign verify "$IMAGE" \
  --certificate-identity-regexp '^https://github.com/RijksICTGilde/base-images/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

# 2. Verify GitHub build provenance
gh attestation verify "oci://$IMAGE" --owner RijksICTGilde

# 3. Inspect the SBOM and provenance attestations in the registry
cosign download sbom "$IMAGE"
cosign verify-attestation "$IMAGE" --type slsaprovenance \
  --certificate-identity-regexp '^https://github.com/RijksICTGilde/base-images/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Hardening summary

- Non-root: uid 101 for `nginx-base`, uid 10001 for `haproxy-redirect`. Both run with a read-only root filesystem.
- Base image pinned by digest, and `apk upgrade` on every build.
- `nginx-base`: security headers on every response including cached assets, static content limited to `GET` and `HEAD`, dotfiles never served, version hidden, one fixed worker, and opt-in proxy locations that follow the backend's method policy.
- Trivy CVE and Dockerfile scans, with results in the Security tab.
- OpenSSF Scorecard analysis.

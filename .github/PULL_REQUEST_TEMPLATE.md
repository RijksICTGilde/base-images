<!-- Thanks for contributing to nginx-base. Keep PRs small and focused. -->

## What & why

<!-- What does this change and why is it needed? Link any related issue. -->

Closes #

## Checklist

- [ ] `docker build .` succeeds and the image still runs as **non-root** (uid 101)
- [ ] Trivy CVE scan is clean (`CRITICAL,HIGH`, `--ignore-unfixed`)
- [ ] Trivy config scan on the `Dockerfile` is clean
- [ ] Security headers verified on **both** `/` and a static asset (`*.css`)
- [ ] Any new GitHub Action is **pinned by full commit SHA** (with a `# vX.Y.Z` comment)
- [ ] Docs (`README.md` / `SECURITY.md`) updated if behaviour changed

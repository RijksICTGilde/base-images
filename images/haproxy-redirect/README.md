# haproxy-redirect

Minimal, hardened HAProxy image that issues an HTTP `302` redirect for every incoming request, with the target URL supplied via a single environment variable.

Intended as a redirect deployment when a project's URL has changed and the old hostname must point to a new one. One redirect per pod (one `TARGET_URL` per deployment).

## Base image

`haproxy:3.2.19-alpine` (HAProxy 3.2 LTS), pinned by digest and rebuilt daily with `apk upgrade` for fresh security patches. Runs as `USER 10001`, no root, no writable paths — compatible with OpenShift `restricted-v2` and read-only root filesystems. Signed (keyless cosign) with an SBOM + provenance attestation; see the repo [`SECURITY.md`](../../SECURITY.md).

## Environment variables

| Variable | Required | Description |
| --- | --- | --- |
| `TARGET_URL` | yes | Absolute URL to redirect to. The original request path and query string are appended. Example: `https://new-host.example.com` |

## Port

Listens on TCP `8080` (HTTP only). TLS termination is expected upstream at the cluster Ingress.

## Behaviour

- Returns `302 Found` for every request.
- `Location` is `${TARGET_URL}` with the original request URI appended (path + query preserved).
- No host-matching, no path rewriting, no health endpoint — a TCP probe on `8080` suffices for liveness/readiness.

Example: with `TARGET_URL=https://new-host.example.com`, a request to `http://<pod>:8080/foo/bar?x=1` returns `Location: https://new-host.example.com/foo/bar?x=1`.

## Local build & test

```bash
task build -- haproxy-redirect
task test  -- haproxy-redirect
# or directly:
docker build -t haproxy-redirect:test images/haproxy-redirect/
docker run --rm -e TARGET_URL=https://example.com -p 8080:8080 haproxy-redirect:test
curl -I http://localhost:8080/foo?bar=1   # -> 302, Location: https://example.com/foo?bar=1
```

# haproxy-redirect

HAProxy image without root that redirects every request with a `302` to a target set by one environment variable. Meant for a project whose URL changed and whose old hostname must point to the new one. One target per pod.

## Base image

Based on `haproxy:*-alpine`. The version and digest are pinned in the [`Dockerfile`](Dockerfile) and bumped by Dependabot. The published image is scanned daily and rebuilt with `apk upgrade` when there is a fixable CVE or an Alpine update. It runs as uid 10001 (group 0), works with OpenShift `restricted-v2` and a read-only root filesystem, and is signed with an SBOM and provenance attestation. See [`SECURITY.md`](../../SECURITY.md).

## Environment variables

| Variable | Required | Description |
| --- | --- | --- |
| `TARGET_URL` | yes | Absolute URL to redirect to, for example `https://new-host.example.com`. A trailing slash is removed and the original path and query are appended. |

Without `TARGET_URL` the image still starts but redirects to the same path on the same host, which is a redirect loop.

## Port

Listens on TCP `8080`, HTTP only. TLS belongs on the cluster Ingress. The image sends no security headers itself, including HSTS.

## Behaviour

- Every request gets `302 Found`, whatever the HTTP method.
- `Location` is `$TARGET_URL` followed by the original path and query. There is no host matching and no path rewriting.
- `/healthz` (liveness) and `/readyz` (readiness) return `200` with body `ok` instead of a redirect. The image has no upstream, so both are the same. These requests are not logged.
- Logs go to stdout in HAProxy `httplog` format.

```yaml
livenessProbe:
  httpGet: { path: /healthz, port: 8080 }
readinessProbe:
  httpGet: { path: /readyz, port: 8080 }
```

With `TARGET_URL=https://new-host.example.com`, a request to `http://<pod>:8080/foo/bar?x=1` returns `Location: https://new-host.example.com/foo/bar?x=1`.

## Local build and test

```bash
task build -- haproxy-redirect
task test  -- haproxy-redirect
# or directly:
docker build -t haproxy-redirect:test images/haproxy-redirect/
docker run --rm -e TARGET_URL=https://example.com -p 8080:8080 haproxy-redirect:test
curl -I http://localhost:8080/foo?bar=1   # 302, Location: https://example.com/foo?bar=1
```

# haproxy-redirect

Non-root HAProxy image that redirects every request with a `302` to the URL in `TARGET_URL`. For a project whose URL changed. One target per pod.

## Base image

Based on `haproxy:*-alpine`, pinned in the [`Dockerfile`](Dockerfile). Runs as uid 10001 (group 0), works with OpenShift `restricted-v2` and a read-only root filesystem. Signed, with an SBOM and provenance attestation. See [`SECURITY.md`](../../SECURITY.md) and the [comparison with upstream](../../README.md#why-our-own-base-images).

## Environment variables

| Variable | Required | Description |
| --- | --- | --- |
| `TARGET_URL` | yes | Absolute URL to redirect to, for example `https://new-host.example.com`. A trailing slash is removed and the original path and query are appended. |

Without `TARGET_URL` the image still starts but redirects to the same path on the same host, which is a redirect loop.

## Port

TCP `8080`, HTTP only. TLS belongs on the cluster Ingress. The image sends no security headers, including HSTS.

## Behaviour

- Every request gets `302 Found`, whatever the HTTP method.
- `Location` is `$TARGET_URL` followed by the original path and query. There is no host matching and no path rewriting.
- `/healthz` and `/readyz` return `200 ok` instead of a redirect and are not logged.
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

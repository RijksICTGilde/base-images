#!/usr/bin/env bash
# Functional test for the haproxy-redirect image. Runs it with a TARGET_URL and
# asserts every request gets a 302 to that target with the path/query preserved.
# Usage: test.sh <image-ref>
set -euo pipefail

IMAGE="${1:?usage: test.sh <image-ref>}"
NAME="haproxy-test-$$"
TARGET="https://new-host.example.com"
trap 'docker rm -f "$NAME" >/dev/null 2>&1 || true' EXIT

echo "== non-root =="
[ "$(docker run --rm "$IMAGE" id -u)" != "0" ] || { echo "FAIL: running as root"; exit 1; }

docker run -d --name "$NAME" -e "TARGET_URL=${TARGET}" -P "$IMAGE" >/dev/null
sleep 2
PORT="$(docker port "$NAME" 8080/tcp | head -1 | sed 's/.*://')"

echo "== 302 redirect with path + query preserved =="
HEAD="$(curl -sI "http://localhost:${PORT}/foo/bar?x=1")"
echo "$HEAD"
echo "$HEAD" | grep -qi "^HTTP/.* 302"                                   || { echo "FAIL: not a 302"; exit 1; }
echo "$HEAD" | grep -qi "^location: ${TARGET}/foo/bar?x=1"               || { echo "FAIL: wrong Location header"; exit 1; }

echo "== health endpoints answer 200, not a redirect =="
for path in /healthz /readyz; do
  [ "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}${path}")" = "200" ] || { echo "FAIL: ${path} not 200"; exit 1; }
  curl -s "http://localhost:${PORT}${path}" | grep -q "ok" || { echo "FAIL: ${path} body empty"; exit 1; }
done

echo "== health probes are not logged =="
curl -s -o /dev/null "http://localhost:${PORT}/healthz"
curl -s -o /dev/null "http://localhost:${PORT}/readyz"
docker logs "$NAME" 2>&1 | grep -q "healthz\|readyz" && { echo "FAIL: probe traffic logged"; exit 1; } || true

echo "PASS: haproxy-redirect issues correct 302 redirects and serves health endpoints"

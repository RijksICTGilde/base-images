#!/usr/bin/env bash
# Functional test for the nginx base image. Builds a small test site on top of
# the given base image and asserts it actually serves it, with the hardening in
# place. Usage: test.sh <base-image-ref>
set -euo pipefail

IMAGE="${1:?usage: test.sh <base-image-ref>}"
NAME="nginx-test-$$"
TMP="$(mktemp -d)"
trap 'docker rm -f "$NAME" >/dev/null 2>&1 || true; rm -rf "$TMP"' EXIT

echo '<html><body>NGINX-BASE-SERVES-OK-7f3a</body></html>' > "$TMP/index.html"
echo '.marker{content:"CSS-SERVES-OK-9b2c"}' > "$TMP/app.css"
echo 'SECRET' > "$TMP/.env"
cat > "$TMP/Dockerfile" <<EOF
FROM ${IMAGE}
COPY index.html /usr/share/nginx/html/index.html
COPY app.css /usr/share/nginx/html/app.css
COPY .env /usr/share/nginx/html/.env
EOF

docker build -t "${NAME}:img" "$TMP"

echo "== non-root =="
[ "$(docker run --rm "${NAME}:img" id -u)" != "0" ] || { echo "FAIL: running as root"; exit 1; }

echo "== nginx config valid =="
docker run --rm "${NAME}:img" nginx -t

docker run -d --name "$NAME" -P "${NAME}:img" >/dev/null
sleep 2
PORT="$(docker port "$NAME" 8080/tcp | head -1 | sed 's/.*://')"

echo "== serves the page (status + body) =="
[ "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/")" = "200" ] || { echo "FAIL: not 200"; exit 1; }
curl -s "http://localhost:${PORT}/"        | grep -q "NGINX-BASE-SERVES-OK-7f3a" || { echo "FAIL: index body not served"; exit 1; }
curl -s "http://localhost:${PORT}/app.css" | grep -q "CSS-SERVES-OK-9b2c"        || { echo "FAIL: asset body not served"; exit 1; }

echo "== security headers on / and on the static asset =="
for path in / /app.css; do
  H="$(curl -sI "http://localhost:${PORT}${path}")"
  for h in "x-content-type-options: nosniff" "x-frame-options: SAMEORIGIN" "referrer-policy" "strict-transport-security" "content-security-policy" "permissions-policy"; do
    echo "$H" | grep -qi "$h" || { echo "FAIL: missing '$h' on ${path}"; exit 1; }
  done
done

echo "== method restriction (POST -> 405) =="
[ "$(curl -s -o /dev/null -w '%{http_code}' -X POST "http://localhost:${PORT}/")" = "405" ] || { echo "FAIL: POST not 405"; exit 1; }

echo "== dotfiles not served (/.env -> not 200) =="
[ "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/.env")" != "200" ] || { echo "FAIL: dotfile served"; exit 1; }

echo "== nginx version hidden =="
curl -sI "http://localhost:${PORT}/" | grep -qi "^server: nginx/" && { echo "FAIL: version exposed"; exit 1; } || true

echo "PASS: nginx image serves content and is hardened"

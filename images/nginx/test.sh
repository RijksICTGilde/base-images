#!/usr/bin/env bash
# Functional test for the nginx base image. Builds a small test site on top of
# the given base image and asserts it actually serves it, with the hardening in
# place. A second part adds a reverse-proxy location the way a consumer would
# and asserts that proxying works without weakening the static hardening.
# Usage: test.sh <base-image-ref>
set -euo pipefail

IMAGE="${1:?usage: test.sh <base-image-ref>}"
NAME="nginx-test-$$"
TMP="$(mktemp -d)"
trap 'docker rm -f "$NAME" >/dev/null 2>&1 || true; rm -rf "$TMP"' EXIT

echo '<html><body>NGINX-BASE-SERVES-OK-7f3a</body></html>' > "$TMP/index.html"
echo '.marker{content:"CSS-SERVES-OK-9b2c"}' > "$TMP/app.css"
echo 'CUSTOM-404-PAGE' > "$TMP/404.html"
echo 'CUSTOM-50X-PAGE' > "$TMP/50x.html"
echo 'SECRET' > "$TMP/.env"

# What a consumer ships to proxy an API: one file in locations.d. The backend
# is a second server block in conf.d (http-scope extension point), listening
# on localhost only, that echoes method + URI so we can see what arrived.
cat > "$TMP/api.conf" <<'EOF'
location /api/ {
    include /etc/nginx/snippets/proxy.conf;
    proxy_pass http://127.0.0.1:8081;
}
EOF
cat > "$TMP/down.conf" <<'EOF'
location /down/ {
    include /etc/nginx/snippets/proxy.conf;
    proxy_pass http://127.0.0.1:9;
}
EOF
cat > "$TMP/backend.conf" <<'EOF'
server {
    listen 127.0.0.1:8081;
    location / {
        default_type text/plain;
        add_header X-Powered-By "LEAKY-FRAMEWORK" always;
        return 200 "BACKEND $request_method $request_uri xff=$http_x_forwarded_for\n";
    }
}
EOF

cat > "$TMP/Dockerfile" <<EOF
FROM ${IMAGE}
COPY index.html /usr/share/nginx/html/index.html
COPY app.css /usr/share/nginx/html/app.css
COPY .env /usr/share/nginx/html/.env
COPY 404.html /usr/share/nginx/html/404.html
COPY 50x.html /usr/share/nginx/html/50x.html
COPY api.conf /etc/nginx/locations.d/api.conf
COPY down.conf /etc/nginx/locations.d/down.conf
COPY backend.conf /etc/nginx/conf.d/backend.conf
EOF

docker build -t "${NAME}:img" "$TMP"

echo "== non-root =="
[ "$(docker run --rm "${NAME}:img" id -u)" != "0" ] || { echo "FAIL: running as root"; exit 1; }

echo "== nginx config valid =="
docker run --rm "${NAME}:img" nginx -t

docker run -d --name "$NAME" -P "${NAME}:img" >/dev/null
sleep 2
PORT="$(docker port "$NAME" 8080/tcp | head -1 | sed 's/.*://')"
URL="http://localhost:${PORT}"
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }

echo "== exactly one worker process (worker_processes auto would be one per node core) =="
WORKERS="$(docker exec "$NAME" ps -o args | grep -c 'nginx: worker process' || true)"
[ "$WORKERS" = "1" ] || { echo "FAIL: expected 1 worker, found ${WORKERS}"; exit 1; }

echo "== serves the page (status + body) =="
[ "$(code "$URL/")" = "200" ] || { echo "FAIL: not 200"; exit 1; }
curl -s "$URL/"        | grep -q "NGINX-BASE-SERVES-OK-7f3a" || { echo "FAIL: index body not served"; exit 1; }
curl -s "$URL/app.css" | grep -q "CSS-SERVES-OK-9b2c"        || { echo "FAIL: asset body not served"; exit 1; }

echo "== security headers on /, on the static asset and on the proxied path =="
for path in / /app.css /api/x; do
  H="$(curl -sI "$URL$path")"
  for h in "x-content-type-options: nosniff" "x-frame-options: SAMEORIGIN" "referrer-policy" "strict-transport-security" "content-security-policy" "permissions-policy"; do
    echo "$H" | grep -qi "$h" || { echo "FAIL: missing '$h' on ${path}"; exit 1; }
  done
done

echo "== static content is GET/HEAD only (POST -> 405), also for cached assets =="
[ "$(code -X POST "$URL/")" = "405" ]        || { echo "FAIL: POST / not 405"; exit 1; }
[ "$(code -X POST "$URL/app.css")" = "405" ] || { echo "FAIL: POST /app.css not 405"; exit 1; }

echo "== dotfiles not served (/.env -> not 200), also under the proxied prefix =="
[ "$(code "$URL/.env")" != "200" ]     || { echo "FAIL: dotfile served"; exit 1; }
[ "$(code "$URL/api/.env")" = "404" ]  || { echo "FAIL: /api/.env not 404"; exit 1; }

echo "== reverse proxy: GET and POST reach the backend with path + query =="
curl -s "$URL/api/items?x=1"         | grep -q "BACKEND GET /api/items?x=1"  || { echo "FAIL: GET not proxied"; exit 1; }
curl -s -X POST "$URL/api/items"     | grep -q "BACKEND POST /api/items"     || { echo "FAIL: POST not proxied"; exit 1; }
curl -s -X DELETE "$URL/api/items/1" | grep -q "BACKEND DELETE /api/items/1" || { echo "FAIL: DELETE not proxied"; exit 1; }

echo "== reverse proxy: asset-looking paths under the prefix go to the backend, not to disk =="
curl -s "$URL/api/report.png" | grep -q "BACKEND GET /api/report.png" || { echo "FAIL: /api/*.png captured by static rules"; exit 1; }

echo "== reverse proxy: X-Forwarded-For is appended, backend's X-Powered-By is hidden =="
curl -s -H 'X-Forwarded-For: 203.0.113.9' "$URL/api/who" | grep -q "xff=203.0.113.9, " || { echo "FAIL: X-Forwarded-For not appended"; exit 1; }
curl -sI "$URL/api/who" | grep -qi "x-powered-by" && { echo "FAIL: backend X-Powered-By leaked"; exit 1; } || true

echo "== custom error pages from the docroot are used (404 and 502) =="
[ "$(code "$URL/does-not-exist")" = "404" ] || { echo "FAIL: missing file not 404"; exit 1; }
curl -s "$URL/does-not-exist" | grep -q "CUSTOM-404-PAGE" || { echo "FAIL: custom 404.html not used"; exit 1; }
[ "$(code "$URL/down/x")" = "502" ] || { echo "FAIL: dead backend not 502"; exit 1; }
curl -s "$URL/down/x" | grep -q "CUSTOM-50X-PAGE" || { echo "FAIL: custom 50x.html not used"; exit 1; }

echo "== health endpoints answer 200 with a body, not from disk =="
for path in /healthz /readyz; do
  [ "$(code "$URL$path")" = "200" ] || { echo "FAIL: ${path} not 200"; exit 1; }
  curl -s "$URL$path" | grep -q "ok" || { echo "FAIL: ${path} body empty"; exit 1; }
done

echo "== health probes are not logged =="
curl -s -o /dev/null "$URL/healthz"
curl -s -o /dev/null "$URL/readyz"
docker logs "$NAME" 2>&1 | grep -q "healthz\|readyz" && { echo "FAIL: probe traffic logged"; exit 1; } || true

echo "== nginx version hidden =="
curl -sI "$URL/" | grep -qi "^server: nginx/" && { echo "FAIL: version exposed"; exit 1; } || true

echo "PASS: nginx image serves content, proxies on request, and is hardened"

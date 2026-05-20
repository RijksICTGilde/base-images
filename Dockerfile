FROM nginxinc/nginx-unprivileged:1.31-alpine

COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 8080

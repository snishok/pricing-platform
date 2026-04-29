FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/nginx.conf

RUN touch /var/run/nginx.pid \
    && chown -R nginx:nginx /var/cache/nginx /var/run/nginx.pid /etc/nginx

USER nginx

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/ >/dev/null 2>&1 || exit 1


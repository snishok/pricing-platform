FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /src
COPY . /src

RUN flutter --version
RUN dart pub get
RUN dart run melos bootstrap
RUN cd packages/app && flutter pub get
RUN cd packages/app && flutter build web --release --dart-define=API_BASE=/api/

FROM nginx:1.27-alpine
COPY --from=build /src/packages/app/build/web /usr/share/nginx/html
COPY packages/app/nginx.conf /etc/nginx/conf.d/default.conf

RUN touch /var/run/nginx.pid \
    && chown -R nginx:nginx /var/cache/nginx /var/run/nginx.pid /usr/share/nginx/html /etc/nginx/conf.d

USER nginx

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/ >/dev/null 2>&1 || exit 1


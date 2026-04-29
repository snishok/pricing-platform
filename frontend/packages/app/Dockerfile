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


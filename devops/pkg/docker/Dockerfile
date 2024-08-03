FROM debian:bookworm-slim AS build
WORKDIR /app

RUN apt -y update \
    && apt install -y --no-install-recommends meson clang curl git xz-utils ca-certificates
RUN curl -fsS https://dlang.org/install.sh | bash -s ldc-1.39.0

COPY ./meson.build ./
COPY ./src/ ./src/
COPY ./subprojects/dmd-fe.wrap ./subprojects/dmd-fe.wrap    
COPY ./subprojects/packagefiles/ ./subprojects/packagefiles/

SHELL ["bash", "-c"]
RUN source ~/dlang/ldc-*/activate \
    && meson setup build --buildtype=release \
    && cd build \
    && ninja

FROM debian:bookworm-slim
WORKDIR /app

COPY --from=build /root/dlang/ldc-1.39.0/lib/ /usr/lib/
COPY --from=build /app/build/marmos ./marmos

RUN useradd -m marmos && chown -R marmos:marmos /app && chmod a=rx marmos
USER marmos

ENTRYPOINT ["/app/marmos"]
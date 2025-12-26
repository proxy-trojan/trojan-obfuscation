FROM alpine:3.20 AS builder

WORKDIR /src
COPY . .

# Build trojan-pro using the repo's canonical build script.
RUN apk add --no-cache \
        bash \
        build-base \
        cmake \
        boost-dev \
        openssl-dev \
        mariadb-connector-c-dev \
    && ./scripts/build-trojan-core.sh --build-type Release

FROM alpine:3.20 AS runtime

# Runtime deps: C++ stdlib + boost runtime components + openssl.
RUN apk add --no-cache \
        libstdc++ \
        boost-system \
        boost-program_options \
        openssl

COPY --from=builder /src/dist/trojan /usr/local/bin/trojan

WORKDIR /config
CMD ["trojan", "config.json"]

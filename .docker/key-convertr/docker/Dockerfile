FROM rust:alpine3.17 AS build-env

RUN apk add --update cargo

RUN rustup toolchain install nightly

COPY .docker/key-convertr key-convertr/

RUN cargo +nightly -Z sparse-registry install --path key-convertr --root /usr/local/bin

FROM alpine:3.17

COPY --from=build-env /usr/local/bin/* /usr/local/bin/

WORKDIR /

# ENTRYPOINT ["/usr/local/bin/key-convertr"]
COPY .docker/key-convertr/start.sh /usr/local/bin/start
RUN chmod u+x /usr/local/bin/start
CMD ["/usr/local/bin/start"]
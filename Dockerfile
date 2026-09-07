FROM alpine:3 AS builder

# This project targets the same toolchain as the nix flake (Gleam 1.18.x).
# The dependency set (e.g. sqlight) requires Gleam >= 1.15.0.
ARG GLEAM_VERSION=1.18.1

RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" > /etc/apk/repositories && \
  echo "http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories && \
  echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \
  apk update && \
  apk add openssl-dev gcc musl-dev gleam rebar3 && \
  apk add --force erlang27 erlang27-dev && \
  test "$(gleam --version | awk '{print $2}')" = "$GLEAM_VERSION" && \
  mkdir /app

WORKDIR /app
COPY ./gleam.toml /app/gleam.toml
COPY ./manifest.toml /app/manifest.toml
COPY ./src /app/src

RUN gleam export erlang-shipment

FROM alpine:3

RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" > /etc/apk/repositories && \
  echo "http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories && \
  echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \
  apk update && \
  apk add openssl erlang27 bash && \
  adduser -s /bin/false -D -u 4000 gleeter

COPY --from=builder --chown=root: /app/build/erlang-shipment /opt/gleeter
COPY --chown=root: ./scripts/gleeter /usr/bin/gleeter

RUN chmod +x /usr/bin/gleeter

USER gleeter
WORKDIR /home/gleeter

ENTRYPOINT ["gleeter"]

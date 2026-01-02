FROM alpine:3.20

RUN apk add --update zig

WORKDIR /app

COPY . /app

ENTRYPOINT [ "sh" ]

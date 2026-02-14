FROM alpine:latest
RUN apk add --no-cache curl
RUN curl -L -o /usr/bin/tuic-server https://github.com/EAimTY/tuic/releases/download/tuic-server-1.0.0/tuic-server-1.0.0-x86_64-unknown-linux-musl \
    || curl -L -o /usr/bin/tuic-server https://github.com/tuic/tuic/releases/download/tuic-server-1.0.0/tuic-server-1.0.0-x86_64-unknown-linux-musl
RUN chmod +x /usr/bin/tuic-server
CMD ["tuic-server", "-c", "/etc/tuic/config.json"]

# Dockerfile.jellyfin-test
FROM alpine:edge

# Enable community repository for Jellyfin
RUN echo "https://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories

RUN addgroup -g 13000 jellyfin && adduser -D -u 13001 -G jellyfin jellyfin

# Install jellyfin and common dependencies
RUN apk update && apk add --no-cache \
    jellyfin \
    jellyfin-web \
    ffmpeg \
    icu-data-full \
    tzdata \
    dotnet8-runtime \
    libva-utils \
    dbus \
    su-exec

# Create volume mount points
RUN mkdir -p /config /cache /media && \
    chown -R jellyfin:jellyfin /config /cache /media /usr/share/webapps/jellyfin-web

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# NOTE: intentionally stays as root here -- entrypoint.sh drops to
# PUID:PGID (default 1000:1000) via su-exec at container start. See
# https://github.com/chefcai/jellyfin-alpine/issues/1

# Expose default port
EXPOSE 8096

# Start Jellyfin server
ENTRYPOINT ["/entrypoint.sh"]
CMD ["jellyfin", \
    "--datadir", "/config", \
    "--cachedir", "/cache", \
    "--ffmpeg", "/usr/bin/ffmpeg", \
    "--webdir", "/usr/share/webapps/jellyfin-web"]

# Dockerfile.jellyfin-test
FROM alpine:edge

# Enable community repository for Jellyfin and Intel VA-API drivers
RUN echo "https://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories

RUN addgroup -g 13000 jellyfin && adduser -D -u 13001 -G jellyfin jellyfin

# Install jellyfin and common dependencies.
#
# VA-API hardware acceleration:
#   * intel-media-driver  -> iHD driver, preferred for Gen 9+ Intel iGPUs
#                            (Apollo/Gemini Lake, Coffee Lake, Tiger Lake, ...)
#   * libva-intel-driver  -> i965 driver, fallback for Gen 8 and below; also
#                            kept on Gen 9 because some codepaths still resolve
#                            i965 first depending on LIBVA_DRIVER_NAME hints.
#   * libva-utils         -> ships /usr/bin/vainfo for verification.
RUN apk update && apk add --no-cache \
    jellyfin \
    jellyfin-web \
    ffmpeg \
    icu-data-full \
    tzdata \
    dotnet8-runtime \
    libva-utils \
    intel-media-driver \
    libva-intel-driver \
    dbus

# Create volume mount points
RUN mkdir -p /config /cache /media && \
    chown -R jellyfin:jellyfin /config /cache /media /usr/share/webapps/jellyfin-web

# Set user
USER jellyfin

# Expose default port
EXPOSE 8096

# Start Jellyfin server
CMD ["jellyfin", \
    "--datadir", "/config", \
    "--cachedir", "/cache", \
    "--ffmpeg", "/usr/bin/ffmpeg", \
    "--webdir", "/usr/share/webapps/jellyfin-web"]

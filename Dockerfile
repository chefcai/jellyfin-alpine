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
                                    "--webdir", "/usr/share/webapps/jellyfin-web" ]

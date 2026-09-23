# jellyfin-alpine — Jellyfin on a pinned Alpine stable release.
#
# Base: alpine:3.24 (stable). Earlier builds tracked alpine:edge; 3.24
# community ships the same jellyfin 10.11.x + jellyfin-ffmpeg 7.1.x, so a
# pinned stable base gives reproducible builds without losing currency.
#
# Size notes (what was removed vs the previous edge build, and why):
#   - dotnet8-runtime: jellyfin 10.11 targets net9.0 and the `jellyfin` apk
#     already depends on aspnetcore9-runtime. The explicit dotnet8 install
#     was a second, unused runtime (~66 MB).
#   - ffmpeg (upstream 8.x): the `jellyfin` apk hard-depends on
#     jellyfin-ffmpeg (the fork Jellyfin is built/tested against, with the
#     tonemap/OpenCL/libplacebo patches). We point --ffmpeg at it and no
#     longer install a second ffmpeg + its libav* libraries.
#   - libva-utils: `vainfo` diagnostic only. libva itself is still pulled in
#     by jellyfin-ffmpeg. Install ad hoc if you need to debug /dev/dri.
#   - dbus: not used by Jellyfin server.
#   - `chown -R` of /usr/share/webapps/jellyfin-web: the web client is served
#     read-only. The chown ran in its own layer, so every file was copied
#     into a new layer (~57 MB duplicate).
FROM alpine:3.24

# Single RUN so user creation, install and cleanup share one layer.
RUN addgroup -g 13000 jellyfin \
 && adduser -D -u 13001 -G jellyfin jellyfin \
 && apk add --no-cache \
        jellyfin \
        jellyfin-web \
        icu-data-full \
        tzdata \
        su-exec \
 && mkdir -p /config /cache /media \
 && chown jellyfin:jellyfin /config /cache /media \
 && rm -rf /usr/share/man /usr/share/doc /usr/share/info

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# NOTE: intentionally stays as root here -- entrypoint.sh drops to
# PUID:PGID (default 1000:1000) via su-exec at container start. See
# https://github.com/chefcai/jellyfin-alpine/issues/1

EXPOSE 8096

ENTRYPOINT ["/entrypoint.sh"]
CMD ["jellyfin", \
    "--datadir", "/config", \
    "--cachedir", "/cache", \
    "--ffmpeg", "/usr/lib/jellyfin-ffmpeg/ffmpeg", \
    "--webdir", "/usr/share/webapps/jellyfin-web"]

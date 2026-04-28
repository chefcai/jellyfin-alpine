# Dockerfile.jellyfin-test
FROM alpine:edge

# Enable community + testing repos. testing carries jellyfin-ffmpeg, libvpl,
# and onevpl-intel-gpu (vpl-gpu-rt); community carries jellyfin and the iHD/i965
# VA drivers.
RUN echo "https://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \
    echo "https://dl-cdn.alpinelinux.org/alpine/edge/testing"   >> /etc/apk/repositories

RUN addgroup -g 13000 jellyfin && adduser -D -u 13001 -G jellyfin jellyfin

# Attempt 1 (alpine-hw-encode): apk-only QSV stack on Gen 9 (Apollo / Gemini Lake).
#
# This recreates as much of the upstream Debian jellyfin-ffmpeg hwaccel stack as
# Alpine packaging exposes today:
#
#   * jellyfin-ffmpeg            -> upstream-blessed ffmpeg fork (testing repo).
#                                   Linked against libvpl.so.2, NOT bundling
#                                   libmfx the way the Debian package does.
#   * intel-media-driver         -> iHD VA driver (Gen 8.5+; covers Apollo/Gemini Lake).
#   * libva-intel-driver         -> i965 fallback; some Gen 9 codepaths still
#                                   resolve i965 first depending on driver hints.
#   * mesa-va-gallium            -> mesa fallback VAAPI driver.
#   * onevpl-intel-gpu + libvpl  -> new VPL runtime + dispatcher for QSV.
#                                   Upstream documents Gen 11+ as the supported
#                                   target; this attempt empirically tests whether
#                                   the 25.4.x runtime that Alpine ships dispatches
#                                   usefully on Gen 9. If QSV_FAIL we escalate to
#                                   a source-built legacy MediaSDK (attempt 2).
#   * intel-gmmlib +
#     intel-graphics-compiler    -> Intel userland GPU support libs (GMM, IGC).
#   * libva-utils                -> ships /usr/bin/vainfo for verification.
RUN apk update && apk add --no-cache \
    jellyfin \
    jellyfin-web \
    jellyfin-ffmpeg \
    icu-data-full \
    tzdata \
    dotnet8-runtime \
    libva-utils \
    intel-media-driver \
    libva-intel-driver \
    mesa-va-gallium \
    onevpl-intel-gpu \
    libvpl \
    intel-gmmlib \
    intel-graphics-compiler \
    dbus

# Expose jellyfin-ffmpeg as /usr/bin/ffmpeg so the BRAIN-37 verification probe
# (which calls plain `ffmpeg`) tests the same binary the daemon uses.
RUN ln -sf /usr/lib/jellyfin-ffmpeg/ffmpeg  /usr/bin/ffmpeg && \
    ln -sf /usr/lib/jellyfin-ffmpeg/ffprobe /usr/bin/ffprobe

# Prefer iHD on Gen 9. Override at run time if a particular probe needs i965.
ENV LIBVA_DRIVER_NAME=iHD

# Volume mount points
RUN mkdir -p /config /cache /media && \
    chown -R jellyfin:jellyfin /config /cache /media /usr/share/webapps/jellyfin-web

USER jellyfin
EXPOSE 8096

# Use jellyfin-ffmpeg (better hwaccel coverage than stock Alpine ffmpeg) as the
# encoder for the daemon.
CMD ["jellyfin", \
    "--datadir", "/config", \
    "--cachedir", "/cache", \
    "--ffmpeg", "/usr/lib/jellyfin-ffmpeg/ffmpeg", \
    "--webdir", "/usr/share/webapps/jellyfin-web"]

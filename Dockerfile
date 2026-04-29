# Dockerfile.jellyfin-test
#
# Attempt 2 (alpine-hw-encode): source-build legacy Intel MediaSDK on Alpine
# so libvpl can dispatch QSV on Gen 9 (Apollo / Gemini Lake). Attempt 1 left
# VAAPI working (iHD) but QSV failing with MFX session error -9 because the
# only QSV runtime apk ships -- onevpl-intel-gpu (vpl-gpu-rt) -- is Gen 11+
# only.
#
# This build adds the missing legacy runtime: Intel-Media-SDK 23.2.2, the last
# tagged release of the archived MediaSDK project. Built in a separate stage
# so build deps don't bloat the runtime image.

# ============================================================================
# Stage 1: build legacy MediaSDK (libmfx / libmfxhw64) on Alpine.
# ============================================================================
FROM alpine:edge AS msdk-build

RUN echo "https://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \
    echo "https://dl-cdn.alpinelinux.org/alpine/edge/testing"   >> /etc/apk/repositories && \
    apk update && apk add --no-cache \
      build-base \
      cmake \
      pkgconf \
      git \
      linux-headers \
      libdrm-dev \
      libva-dev \
      libpciaccess-dev

WORKDIR /src
RUN git clone --depth 1 --branch intel-mediasdk-23.2.2 \
      https://github.com/Intel-Media-SDK/MediaSDK.git

WORKDIR /src/MediaSDK/build
# Alpine/musl doesn't transitively expose <cstdint> via other system headers
# the way glibc does. MediaSDK 23.2.2 sources rely on uint8_t etc. being
# visible without an explicit include in several files (e.g.
# api/mfx_dispatch/linux/mfxparser.cpp). Inject the includes globally instead
# of patching every offending file.
ENV CFLAGS="-include stdint.h -include stddef.h"
ENV CXXFLAGS="-include cstdint -include cstddef"
# BUILD_RUNTIME=ON builds the dispatcher + libmfxhw64.so without the samples,
# tools, tests we don't need.
RUN cmake \
      -DCMAKE_INSTALL_PREFIX=/opt/mediasdk \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_RUNTIME=ON \
      -DBUILD_SAMPLES=OFF \
      -DBUILD_TOOLS=OFF \
      -DBUILD_TESTS=OFF \
      -DENABLE_OPENCL=OFF \
      -DENABLE_X11=OFF \
      -DENABLE_X11_DRI3=OFF \
      -DENABLE_WAYLAND=OFF \
      -DMFX_ENABLE_KERNELS=ON \
      .. && \
    make -j"$(nproc)" && \
    make install && \
    strip --strip-unneeded /opt/mediasdk/lib/libmfxhw64.so.1.35 && \
    strip --strip-unneeded /opt/mediasdk/lib/mfx/*.so && \
    rm -f /opt/mediasdk/lib/libmfx.so /opt/mediasdk/lib/libmfx.so.1 \
          /opt/mediasdk/lib/libmfx.so.1.35 && \
    rm -rf /opt/mediasdk/include /opt/mediasdk/lib/pkgconfig \
           /opt/mediasdk/share && \
    echo "=== installed mediasdk files (post-strip) ===" && \
    find /opt/mediasdk -type f -exec ls -la {} + && \
    du -sh /opt/mediasdk

# ============================================================================
# Stage 2: runtime image.
# ============================================================================
FROM alpine:edge

RUN echo "https://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \
    echo "https://dl-cdn.alpinelinux.org/alpine/edge/testing"   >> /etc/apk/repositories

RUN addgroup -g 13000 jellyfin && adduser -D -u 13001 -G jellyfin jellyfin

# Same Intel media stack as attempt 1 plus the runtime libs MediaSDK needs:
# libstdc++ (C++ runtime), libdrm/libva/libpciaccess (already pulled by other
# packages but pinned here for documentation).
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
    libstdc++ \
    libdrm \
    libva \
    libpciaccess \
    dbus

# Install legacy MediaSDK runtime from build stage.
COPY --from=msdk-build /opt/mediasdk /opt/mediasdk

# Make libmfx + libmfxhw64 discoverable by the libvpl dispatcher and ffmpeg.
# The dispatcher checks ldconfig paths and MFX_DRIVER_DIR. Symlink into
# /usr/lib so dlopen with default paths resolves them, then export
# MFX_DRIVER_DIR for any code path that prefers an explicit hint.
RUN set -e; \
    cd /opt/mediasdk/lib && \
    for f in libmfx*.so* ; do \
      [ -e "$f" ] && ln -sf "/opt/mediasdk/lib/$f" "/usr/lib/$f" || true; \
    done; \
    ldconfig /usr/lib /opt/mediasdk/lib 2>/dev/null || true; \
    ls -la /usr/lib/libmfx* /opt/mediasdk/lib/libmfx* 2>&1 | head -20

ENV LIBVA_DRIVER_NAME=iHD
ENV MFX_DRIVER_DIR=/opt/mediasdk/lib
ENV LD_LIBRARY_PATH=/opt/mediasdk/lib

# Expose jellyfin-ffmpeg as /usr/bin/ffmpeg for the verification probe.
RUN ln -sf /usr/lib/jellyfin-ffmpeg/ffmpeg  /usr/bin/ffmpeg && \
    ln -sf /usr/lib/jellyfin-ffmpeg/ffprobe /usr/bin/ffprobe

RUN mkdir -p /config /cache /media && \
    chown -R jellyfin:jellyfin /config /cache /media /usr/share/webapps/jellyfin-web

USER jellyfin
EXPOSE 8096

CMD ["jellyfin", \
    "--datadir", "/config", \
    "--cachedir", "/cache", \
    "--ffmpeg", "/usr/lib/jellyfin-ffmpeg/ffmpeg", \
    "--webdir", "/usr/share/webapps/jellyfin-web"]

# chefcai/jellyfin-alpine — Dockerfile
#
# The repo name keeps "alpine" for continuity, but the base flipped from
# Alpine to Debian on 2026-04-28 (BRAIN-37). See ## Background.
#
# ## Background
#
# squirttle's iGPU is UHD 605 (Gemini Lake / Intel gen 9). For QSV at
# runtime, gen 9 needs the *legacy* Intel Media SDK (libmfx /
# libmfxhw64). Alpine edge only ships the modern oneVPL GPU runtime
# (`onevpl-intel-gpu`, gen 11+) plus the `libvpl` dispatcher — there is
# no `intel-mediasdk` / legacy `libmfx` package available. The previous
# Alpine build had VA-API decode working via `intel-media-driver` (iHD)
# but ffmpeg's QSV path failed at runtime with `MFX_ERR_UNSUPPORTED (-9)`
# because no MediaSDK was dispatchable.
#
# The upstream `jellyfin/jellyfin` Debian image bundles `jellyfin-ffmpeg`
# with both legacy `libmfxhw64.so` (gen 9) and modern `libmfx-gen.so` /
# `libvpl.so.2` (gen 11+), plus `iHD_drv_video.so`, `i965_drv_video.so`
# and `radeonsi_drv_video.so` in `/usr/lib/jellyfin-ffmpeg/lib/dri/`.
# Verified working on Gemini Lake. Vendoring the legacy MediaSDK from
# source on Alpine is fragile and ongoing work; switching base is the
# proven path.
FROM jellyfin/jellyfin:latest

USER root

# `vainfo` on PATH for in-container VA-API verification. The upstream
# image already ships `/usr/lib/jellyfin-ffmpeg/vainfo`, but BRAIN-25 /
# BRAIN-37 verification scripts call `vainfo` directly.
RUN apt-get update \
 && apt-get install -y --no-install-recommends vainfo \
 && rm -rf /var/lib/apt/lists/*

# Inherit upstream ENTRYPOINT (/jellyfin/jellyfin), USER (root), CMD,
# EXPOSE 8096, WORKDIR and volume hints unchanged. The previous Alpine
# image ran as uid 13001 / gid 13000; the new image runs as root inside
# the container (matching upstream conventions). Files in /config,
# /cache and /media keep working under the existing host-side ownership
# because root has access regardless. If we later want to drop
# privileges, that's a follow-up — it's not required for QSV to work.

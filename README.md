# jellyfin-alpine

A thin Docker image for [Jellyfin](https://jellyfin.org/) on top of the
upstream `jellyfin/jellyfin` Debian base, published to GHCR with a
branch-name → image-tag CI mapping for easy iteration.

> The repo name keeps "alpine" for continuity. The base flipped from
> Alpine to Debian on 2026-04-28 — see [BRAIN-37](https://chefcai.atlassian.net/browse/BRAIN-37)
> and the **Why Debian?** section below.

## Image

```
ghcr.io/chefcai/jellyfin-alpine:latest
```

## Usage

```yaml
services:
  jellyfin:
    image: ghcr.io/chefcai/jellyfin-alpine:latest
    container_name: jellyfin
    ports:
      - "8096:8096"
    volumes:
      - ./config:/config
      - ./cache:/cache
      - /mnt/media:/media:ro
    # Hardware acceleration on Intel iGPU hosts (VA-API / QSV):
    devices:
      - /dev/dri:/dev/dri
    group_add:
      - "<host render gid>"   # find with: getent group render
    restart: unless-stopped
```

## Why Debian?

Originally Alpine. squirttle's iGPU is **UHD 605 (Gemini Lake / Intel
gen 9)**, and QSV runtime on gen 9 needs the **legacy Intel Media SDK**
(`libmfx` / `libmfxhw64`). Alpine edge only packages the modern oneVPL
GPU runtime (`onevpl-intel-gpu`, gen 11+) and the `libvpl` dispatcher;
the legacy MediaSDK isn't available. With the Alpine build, `vainfo`
worked but ffmpeg's QSV init failed with `MFX_ERR_UNSUPPORTED (-9)`.

The upstream `jellyfin/jellyfin` image bundles `jellyfin-ffmpeg` with
both legacy `libmfxhw64.so` (gen 9) and modern `libmfx-gen.so` /
`libvpl.so.2` (gen 11+), plus the iHD/i965/radeonsi VA-API drivers, all
in `/usr/lib/jellyfin-ffmpeg/lib/`. Verified working on Gemini Lake.

## What this image adds on top of upstream

- `vainfo` on PATH for in-container VA-API verification.
- The branch-name → image-tag CI mapping (see below) so we can iterate
  on a branch and consume the result on squirttle without touching
  `:latest`.

Hardware acceleration verification:

```
docker exec jellyfin vainfo
```

You should see `VAEntrypointVLD` (decode) and `VAEntrypointEncSlice`
(encode) entrypoints listed for H264 and HEVC. To probe the QSV runtime
specifically (the bit that broke before BRAIN-37):

```
docker exec jellyfin sh -c '
  /usr/lib/jellyfin-ffmpeg/ffmpeg -hide_banner -loglevel error \
    -init_hw_device qsv=qs:vendor_id=0x8086 \
    -f lavfi -i nullsrc=size=1280x720:duration=0.1 \
    -c:v h264_qsv -low_power 1 -f null - 2>&1 | head'
```

If that completes silently (no `MFX_ERR_UNSUPPORTED`), the QSV runtime
is working.

## Build

Builds run in GitHub Actions (`.github/workflows/build.yml`) and push to
GHCR (`ghcr.io/chefcai/jellyfin-alpine`). **Local `docker build` is not
part of the workflow** — edit the Dockerfile, commit, push, let CI
build, then pull.

### Branch / tag → image tag mapping

Driven by `docker/metadata-action@v5`:

| Trigger                      | Image tags pushed                                              |
| ---------------------------- | -------------------------------------------------------------- |
| push to `main`               | `:latest`, `:<jellyfin-version>`, `:main-<sha>`                |
| push to any other branch     | `:<slugified-branch>` (e.g. `:hw-encode`), `:<branch>-<sha>`   |
| git tag `vX.Y.Z`             | `:vX.Y.Z`                                                      |
| pull request                 | `:pr-<num>`                                                    |
| schedule (daily 06:15 UTC)   | rebuild on `main` if upstream Jellyfin published a new version |

`<jellyfin-version>` comes from the `org.opencontainers.image.version`
label of `jellyfin/jellyfin:latest` at build time. The
`:<branch>-<sha>` tag is always pushed and gives an immutable pin for
rollback.

## Notes

- Runs as **root** inside the container (matches upstream
  `jellyfin/jellyfin`). The previous Alpine image ran as uid `13001` /
  gid `13000`; the host must still pass `/dev/dri` and the appropriate
  `render` GID via `group_add` for hwaccel.
- Jellyfin version is whatever upstream `jellyfin/jellyfin:latest`
  ships at build time.
- Port `8096` is exposed by default.

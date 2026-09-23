# jellyfin-alpine

A minimal, Alpine-based Docker image for [Jellyfin](https://jellyfin.org/) that is significantly smaller than the official community image.

## Why?

The official Jellyfin Docker image is based on Debian and carries a lot of weight. This image installs Jellyfin directly from the Alpine stable (`3.24`) community repository using `apk`, resulting in a leaner image with a smaller attack surface.

## Hardware encoding

**Hardware encoding is disabled in this `:latest` image.** Transcoding runs on CPU. No Intel iGPU drivers, no QSV runtime, no OpenCL runtime are installed (the VA-API client libraries come in as dependencies of `jellyfin-ffmpeg`).

For Intel iGPU hardware acceleration (VA-API + QSV), use builds from the `alpine-hw-encode` branch:

```
ghcr.io/chefcai/jellyfin-alpine:alpine-hw-encode
```

That branch adds `intel-media-driver` (iHD VA-API driver), `libvpl` (QSV dispatcher), and a source-built MediaSDK 23.2.2 runtime so QSV dispatches on legacy Gen 9 (Apollo Lake / Gemini Lake) hardware. See the [alpine-hw-encode README](https://github.com/chefcai/jellyfin-alpine/blob/alpine-hw-encode/README.md) for setup, including the `/dev/dri` device mount and `render` group_add the host needs to provide.

Note: HDR→SDR tonemapping is a separate concern from codec encoding and depends on the iGPU having enough OpenCL compute resources for the tonemap kernel. Gen 11+ Intel iGPUs (Tiger Lake / Alder Lake / N100-class) handle it fine; Gen 9 / Apollo Lake cannot — its 12 EUs run out of resources during the OpenCL kernel regardless of image. On Gen 9 you should keep `EnableTonemapping=false` and accept washed-out colors on HDR titles, or transcode HDR sources to SDR offline.

## Image

```
ghcr.io/chefcai/jellyfin-alpine:latest
```

Builds dispatched from a non-`main` branch (`gh workflow run build.yml --ref <branch>`)
publish only `:branch-<branch-name>`; `:latest` and the version tag are published from `main` only.

## Usage

```yaml
services:
  jellyfin:
    image: ghcr.io/chefcai/jellyfin-alpine:latest
    container_name: jellyfin
    user: "13001:13000"
    ports:
      - "8096:8096"
    volumes:
      - ./config:/config
      - ./cache:/cache
      - /mnt/media:/media:ro
    restart: unless-stopped
```

## What's included

Base: `alpine:3.24`. Installed via `apk` from Alpine 3.24 community:

- `jellyfin` + `jellyfin-web` (pulls in `aspnetcore9-runtime` and `jellyfin-ffmpeg`)
- `icu-data-full`
- `tzdata`
- `su-exec`

Jellyfin is started with `--ffmpeg /usr/lib/jellyfin-ffmpeg/ffmpeg` (Jellyfin's
own ffmpeg fork, which includes the `tonemapx` CPU tonemapping filter).

### Size history

| Build | On-disk | Compressed |
|---|---:|---:|
| `alpine:edge` + `ffmpeg` + `dotnet8-runtime` + `libva-utils` + `dbus`, `chown -R` of web dir in its own layer | 607 MB | 267.7 MB |
| `alpine:3.24`, jellyfin-ffmpeg only, no extra runtime/tools, single install layer | 400 MB | 168.3 MB |

What was removed and why:

- `dotnet8-runtime` — Jellyfin 10.11 targets .NET 9 (`aspnetcore9-runtime` is
  already a dependency of the `jellyfin` package); the .NET 8 runtime was unused.
- `ffmpeg` (upstream) — the `jellyfin` package already depends on
  `jellyfin-ffmpeg`; two ffmpeg builds were installed and only one was used.
- `libva-utils` (`vainfo`) and `dbus` — not used by the server.
- `chown -R` of `/usr/share/webapps/jellyfin-web` in a separate layer — the
  web client is served read-only; the extra layer duplicated ~57 MB.

## Build

The image is built automatically on every push to `main` via GitHub Actions and pushed to the GitHub Container Registry (`ghcr.io`).

## Notes

- Runs as a dedicated `jellyfin` user (uid `13001`, gid `13000`)
- Jellyfin version is whatever Alpine 3.24 community provides at build time (the CI version probe uses the same `alpine:3.24` image as the Dockerfile)
- Port `8096` is exposed by default

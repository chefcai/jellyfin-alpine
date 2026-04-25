# jellyfin-alpine

A minimal, Alpine-based Docker image for [Jellyfin](https://jellyfin.org/) that is significantly smaller than the official community image.

## Why?

The official Jellyfin Docker image is based on Debian and carries a lot of weight. This image installs Jellyfin directly from the Alpine edge community repository using `apk`, resulting in a leaner image with a smaller attack surface.

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

Installed via `apk` from Alpine edge community:

- `jellyfin` + `jellyfin-web`
- `ffmpeg`
- `dotnet8-runtime`
- `icu-data-full`
- `tzdata`
- `libva-utils`
- `dbus`

## Build

The image is built automatically on every push to `main` via GitHub Actions and pushed to the GitHub Container Registry (`ghcr.io`).

## Notes

- Runs as a dedicated `jellyfin` user (uid `13001`, gid `13000`)
- Jellyfin version is determined by whatever Alpine edge community provides at build time
- Port `8096` is exposed by default

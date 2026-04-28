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
    # Hardware acceleration on Intel iGPU hosts (VA-API / QSV):
    devices:
      - /dev/dri:/dev/dri
    group_add:
      - "<host render gid>"   # e.g. 107 on Debian/Ubuntu, find with: getent group render
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
- `intel-media-driver` — iHD VA-API driver, preferred for Intel Gen 9+ iGPUs
- `libva-intel-driver` — i965 VA-API driver, fallback for older / mixed paths
- `dbus`

To verify hardware acceleration is wired up at runtime:

```
docker exec jellyfin vainfo
```

You should see `VAEntrypointVLD` (decode) and `VAEntrypointEncSlice` (encode) entrypoints listed for H264 and HEVC.

## Build

Builds run in GitHub Actions (`.github/workflows/build.yml`) and push to GHCR (`ghcr.io/chefcai/jellyfin-alpine`). **Local `docker build` is not part of the workflow** — edit the Dockerfile, commit, push, let CI build, then pull.

### Branch / tag → image tag mapping

Driven by `docker/metadata-action@v5`:

| Trigger                      | Image tags pushed                                              |
| ---------------------------- | -------------------------------------------------------------- |
| push to `main`               | `:latest`, `:<jellyfin-version>`, `:main-<sha>`                |
| push to any other branch     | `:<slugified-branch>` (e.g. `:hw-encode`), `:<branch>-<sha>`   |
| git tag `vX.Y.Z`             | `:vX.Y.Z`                                                      |
| pull request                 | `:pr-<num>`                                                    |
| schedule (daily 06:15 UTC)   | rebuild on `main` if upstream Jellyfin published a new version |

The `:<branch>-<sha>` tag is always pushed and gives an immutable pin for rollback.

## Notes

- Runs as a dedicated `jellyfin` user (uid `13001`, gid `13000`).
- Jellyfin version is determined by whatever Alpine edge community provides at build time.
- Port `8096` is exposed by default.
- VA-API drivers are present in the image, but the host must still pass `/dev/dri` and the appropriate `render` GID into the container — see the Usage example above.

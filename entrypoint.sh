#!/bin/sh
# Runtime PUID/PGID support (linuxserver.io-style).
# https://github.com/chefcai/jellyfin-alpine/issues/1
#
# Defaults to a generic 1000:1000 so this image runs out of the box on any
# host. Override with `-e PUID=... -e PGID=...` (or the PUID/PGID entries in
# docker-compose) to match your existing bind-mount ownership.
#
# Only app-state directories are remapped here -- never a media-library
# mount, which stays whatever the host already owns. Recursively chown'ing
# a large media library on every container start would be slow and is
# unnecessary; the deployer is expected to have already set that dir's
# ownership per the README.
set -e

PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

CUR_UID=$(id -u jellyfin)
CUR_GID=$(id -g jellyfin)

if [ "$PGID" != "$CUR_GID" ]; then
  sed -i "s/^jellyfin:x:[0-9]*:/jellyfin:x:${PGID}:/" /etc/group
fi
if [ "$PUID" != "$CUR_UID" ]; then
  sed -i "s/^jellyfin:x:[0-9]*:[0-9]*:/jellyfin:x:${PUID}:${PGID}:/" /etc/passwd
fi

for dir in /config /cache; do
  if [ -d "$dir" ]; then
    owner="$(stat -c '%u:%g' "$dir" 2>/dev/null || echo '?')"
    if [ "$owner" != "${PUID}:${PGID}" ]; then
      chown -R "${PUID}:${PGID}" "$dir"
    fi
  fi
done

# Preserve access to any supplementary groups root has in this container
# (e.g. a `group_add`-mounted GPU render group for hardware transcoding via
# /dev/dri) -- su-exec's initgroups(3) call only picks up memberships
# recorded in /etc/group, so make jellyfin a member of every group root
# currently belongs to before dropping privileges.
for gid in $(id -G); do
  gname=$(getent group "$gid" | cut -d: -f1)
  [ -n "$gname" ] && [ "$gname" != "jellyfin" ] && addgroup jellyfin "$gname" 2>/dev/null || true
done

exec su-exec jellyfin "$@"

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

# TMPDIR (see docker-compose's TMPDIR=/cache/tmp) is ephemeral scratch space
# jellyfin/.NET recreate on every start. On a network-mounted /cache it can
# accumulate stale named pipes/sockets left behind by a previous process's
# lifetime (observed in production: leftover .NET diagnostic sockets from an
# earlier container run), and removing/chowning those over NFS can fail with
# "I/O error" on that specific path. Wipe it up front so leftover cruft from
# a prior run can't linger.
rm -rf /cache/tmp 2>/dev/null || true

for dir in /config /cache; do
  if [ -d "$dir" ]; then
    owner="$(stat -c '%u:%g' "$dir" 2>/dev/null || echo '?')"
    if [ "$owner" != "${PUID}:${PGID}" ]; then
      # Best-effort: some network filesystems mishandle certain special
      # files (sockets/FIFOs) under chown. A single unchownable leftover
      # path used to abort this whole script under `set -e` and crash-loop
      # the container -- don't let that happen; just report it.
      chown -R "${PUID}:${PGID}" "$dir" \
        || echo "[entrypoint] warning: chown of $dir hit at least one error (continuing)" >&2
    fi
  fi
done

mkdir -p /cache/tmp
chown "${PUID}:${PGID}" /cache/tmp 2>/dev/null || true

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

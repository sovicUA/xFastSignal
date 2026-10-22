#!/usr/bin/env bash
# Deploy the xSignalRelay image to the server (run by CI in vars.FASTSIGNAL_STAND_DIR; can be run by hand there):
#   ./deploy.sh <image_tag>
# Stops the relay, backs up data/ (SQLite) to backups/, starts the given tag, waits until the relay reports signal-cli
# as Online. Refuses to run without .env, appsettings.Production.json or the Docker network "signal" (xSignal).
set -euo pipefail
cd "$(dirname "$0")"

TAG="${1:?usage: deploy.sh <image_tag>}"
[ -f .env ] || { echo "Missing .env (see .env.example)"; exit 1; }
# Without it Docker would create a directory in its place
[ -f appsettings.Production.json ] || { echo "Missing appsettings.Production.json (see appsettings.Production.json.example)"; exit 1; }
docker network inspect signal >/dev/null 2>&1 || { echo "Missing Docker network \"signal\" (xSignal: README.md)"; exit 1; }

# CI runs this as root: keep .env (rewritten below) and the backups owned by the directory's owner
restore_owner() { chown -R "$(stat -c %u:%g .)" .env backups 2>/dev/null || true; }
trap restore_owner EXIT

# The tag goes into .env, so `docker compose` commands by hand use the deployed image too
if grep -q '^FASTSIGNAL_TAG=' .env; then sed -i "s/^FASTSIGNAL_TAG=.*/FASTSIGNAL_TAG=$TAG/" .env; else echo "FASTSIGNAL_TAG=$TAG" >> .env; fi
env_value() { sed -n "s/^$1=//p" .env; }
KEEP_BACKUPS="$(env_value KEEP_BACKUPS)"
PREFIX="$(env_value FASTSIGNAL_IMAGE_PREFIX)"
HOST="$(env_value FASTSIGNAL_HOST)"
dc() { docker compose --env-file .env -f compose.yml "$@"; }

echo "== image $PREFIX/xsignalrelay:$TAG"
# Tags are commit hashes (immutable): a local copy (built by CI on this host) is used as is
docker image inspect "$PREFIX/xsignalrelay:$TAG" >/dev/null 2>&1 || docker pull "$PREFIX/xsignalrelay:$TAG"

echo "== stop + backup"
mkdir -p data
# Stopped, so the SQLite database is consistent in the archive
dc stop
# The database holds the recipients' numbers: readable by the directory's owner only
umask 077
mkdir -p backups
chmod 700 backups
# UTC with a "Z" suffix: the CI job container has no time zone data
stamp="$(date -u +%Y%m%d-%H%M%SZ)"
# Read data/ from a container: the relay writes it as root
docker run --rm -v "$PWD/data:/data:ro" --entrypoint tar "$PREFIX/xsignalrelay:$TAG" -C /data -cz . > "backups/fastsignal-$stamp.tar.gz"
ls -1t backups/fastsignal-*.tar.gz | tail -n +"$((${KEEP_BACKUPS:-10} + 1))" | xargs -r rm -f

echo "== start"
dc up -d --remove-orphans

echo "== health check"
# The relay pings signal-cli at startup and every 30 s: "state":"Online" once it answered
for _ in $(seq 60); do
    if curl -fsS "https://$HOST/api/status" 2>/dev/null | grep -q '"state":"Online"'; then
        echo "xSignalRelay $TAG is up"
        exit 0
    fi
    sleep 2
done
echo "the relay did not report signal-cli Online (is the stack \"signal\" up?)"; dc ps; dc logs --tail 30 relay; exit 1

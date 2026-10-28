#!/usr/bin/env bash
# Usage: scripts/deploy.sh [--dry-run]. May be called from any directory.
set -euo pipefail

fail() { printf 'Deploy error: %s\n' "$*" >&2; exit 1; }
trap 'printf "Deploy failed (line %s).\n" "$LINENO" >&2; exit 1' ERR

DRY_RUN=()
case "$#" in
    0) ;;
    1) [[ "$1" == '--dry-run' ]] || fail 'Expected --dry-run'; DRY_RUN=(--dry-run) ;;
    *) fail 'Usage: scripts/deploy.sh [--dry-run]' ;;
esac

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)
LOCAL_DIR="$REPO_ROOT/site/"
REMOTE='devops'
REMOTE_DIR='/var/www/devops-site/'
SITE_URL='https://devops.local/'
CA_CERT="${HOME}/devops.crt"

[[ -f "${LOCAL_DIR}index.html" ]] || fail 'site/index.html is missing; synchronization cancelled'
[[ -z "$(git -C "$REPO_ROOT" status --porcelain)" ]] || fail 'Commit all changes before deployment (including staged and untracked files)'
[[ -r "$CA_CERT" ]] || fail "Certificate is missing: $CA_CERT"

# One SSH invocation, used only by rsync. Reuse a connection between repeated deployments.
SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=5 -o ControlMaster=auto -o ControlPersist=60 -o ControlPath=${HOME}/.ssh/devops-deploy-%C"
rsync -avz --delete --chmod=D755,F644 "${DRY_RUN[@]}" -e "$SSH_COMMAND" "$LOCAL_DIR" "$REMOTE:$REMOTE_DIR"

COMMIT=$(git -C "$REPO_ROOT" rev-parse --short HEAD)
if (( ${#DRY_RUN[@]} )); then
    printf 'Dry run OK: commit %s (server unchanged).\n' "$COMMIT"
    exit 0
fi
curl --noproxy devops.local --cacert "$CA_CERT" --fail --silent --show-error --connect-timeout 5 --max-time 15 "$SITE_URL" >/dev/null
printf 'Deploy OK: commit %s.\n' "$COMMIT"

#!/usr/bin/env bash
# Turns a stock node:22-bookworm container into what deploy/container/Dockerfile builds, then starts
# the office with start.sh. It's for Docker hosts that run Compose files but don't build images,
# like Hostinger's Docker Manager: deploy/container/compose.yaml clones the repository into
# /opt/agent-office and runs this from it.
#
# All of it lands in the container's own filesystem, so a restart goes straight to start.sh and a
# recreated container (a new version of the office) does it all again, in a few minutes. What the
# office keeps is on the volume at /data, as with the image.
set -euo pipefail
APP=/opt/agent-office
READY=/etc/agent-office/image-ready

say() { echo "agent-office-bootstrap: $*"; }

if [[ ! -f $READY ]]; then
  say "installing the office's packages (first start of this container)"
  export DEBIAN_FRONTEND=noninteractive
  # The Dockerfile's packages, and the GitHub CLI from GitHub's own apt repo.
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends openssh-server sudo tini procps ca-certificates curl git less build-essential python3 >/dev/null
  install -d -m 755 /etc/apt/keyrings
  curl -fsSLo /etc/apt/keyrings/githubcli-archive-keyring.gpg https://cli.github.com/packages/githubcli-archive-keyring.gpg
  chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    >/etc/apt/sources.list.d/github-cli.list
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends gh >/dev/null
  rm -rf /var/lib/apt/lists/*

  say "building the office ($(git -C $APP log -1 --format='%h %s'))"
  cd $APP
  # No install scripts, as in the Dockerfile: `prepare` would build a second time.
  npm ci --ignore-scripts --no-audit --no-fund
  npm run build
  npm prune --omit=dev --ignore-scripts --no-audit --no-fund
  $APP/deploy/container/install.sh
  install -d -m 755 /etc/agent-office
  touch $READY
fi

exec $APP/deploy/container/start.sh

#!/usr/bin/env bash
set -euo pipefail

# Tycoon POS production deployment
# Run from the repository root on the VPS.
# Override WEB_ROOT if your nginx root differs.

WEB_ROOT="${WEB_ROOT:-/var/www/pos.tycoon.technology}"
BACKUP_ROOT="${BACKUP_ROOT:-/var/backups/tycoon-pos}"
BRANCH="${BRANCH:-main}"
STAMP="$(date +%Y%m%d-%H%M%S)"

if [[ ! -f pubspec.yaml ]]; then
  echo "ERROR: Run this script from the Flutter repository root."
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "ERROR: Flutter is not installed or not in PATH on this VPS."
  exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
  echo "Installing rsync..."
  sudo apt-get update -y
  sudo apt-get install -y rsync
fi

echo "==> Updating source"
git fetch origin
git switch "$BRANCH"
git reset --hard "origin/$BRANCH"

echo "==> Getting Flutter packages"
flutter pub get

echo "==> Building production web app"
flutter build web --release --base-href=/

echo "==> Preparing backup"
sudo mkdir -p "$BACKUP_ROOT" "$WEB_ROOT"
if [[ -n "$(sudo find "$WEB_ROOT" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
  sudo tar -czf "$BACKUP_ROOT/pos-$STAMP.tar.gz" -C "$WEB_ROOT" .
fi

echo "==> Publishing build atomically"
STAGE="${WEB_ROOT}.stage-$STAMP"
sudo rm -rf "$STAGE"
sudo mkdir -p "$STAGE"
sudo rsync -a --delete build/web/ "$STAGE"/
sudo chown -R www-data:www-data "$STAGE"

OLD="${WEB_ROOT}.old-$STAMP"
sudo mv "$WEB_ROOT" "$OLD"
sudo mv "$STAGE" "$WEB_ROOT"
sudo rm -rf "$OLD"

echo "==> Validating nginx"
sudo nginx -t
sudo systemctl reload nginx

echo "==> Deployment complete"
echo "Live root: $WEB_ROOT"
echo "Backup: $BACKUP_ROOT/pos-$STAMP.tar.gz"
echo "Commit: $(git rev-parse --short HEAD)"

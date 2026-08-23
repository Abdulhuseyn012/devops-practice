#!/bin/bash
SRC="$1"
DEST="$HOME/backups"
mkdir -p "$DEST"
tar -czf "$DEST/backup-$(date +%F-%H%M).tar.gz" "$SRC"
echo "Backup created in $DEST"



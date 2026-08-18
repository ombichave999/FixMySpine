#!/bin/bash
# Builds, packages DMG, pushes code to private repo, and publishes release to public Sparkle feed with Ed25519 signature.
# Usage:  bash push_update.sh [new_version] [release_notes]
exec bash "$(dirname "$0")/build_main.sh" "$@"


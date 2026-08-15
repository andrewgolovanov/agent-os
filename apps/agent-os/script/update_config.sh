#!/usr/bin/env bash

# Public update metadata. The private Ed25519 key lives only in the release
# operator's Keychain (account: agent-os) or in the release CI secret.
SPARKLE_KEY_ACCOUNT="agent-os"
SPARKLE_PUBLIC_KEY="kGvaJaXKh13F6Fff/wuMgCH/K8uFbwxe13PZLuad9RE="
SPARKLE_FEED_URL="https://github.com/andrewgolovanov/agent-os/releases/latest/download/appcast.xml"
SPARKLE_DOWNLOAD_URL_ROOT="https://github.com/andrewgolovanov/agent-os/releases/download"

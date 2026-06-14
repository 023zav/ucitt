#!/bin/bash
# SessionStart hook: install a Swift toolchain so `swift build` / `swift test`
# work in Claude Code on the web.
#
# Why this is unusual: the network policy in the web environment blocks
# download.swift.org (official toolchains) and Docker Hub's blob CDN
# (production.cloudfront.docker.com). The one reliable path is Google's
# pull-through cache of Docker Hub, mirror.gcr.io, which is allowlisted AND
# serves image blobs inline. So we fetch the layers of the official
# swift:6.1.2-noble image (Ubuntu 24.04, matching the host) by their
# content-addressed digests and unpack them into /opt/swift. No Docker daemon,
# no auth, no manifest call (digests are pinned), so no rate limit.
set -euo pipefail

# Only needed in the remote (web) environment; locally you have your own Swift.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

SWIFT_ROOT=/opt/swift
SWIFT_BIN="$SWIFT_ROOT/usr/bin/swift"

# swift:6.1.2-noble, linux/amd64 — pinned layer digests (content-addressed).
REGISTRY="https://mirror.gcr.io/v2/library/swift/blobs"
LAYERS=(
  "sha256:76249c7cd50397d2e8c06a75106723d057deaba0ffbc7f4af1bb02bcf71d81cf"
  "sha256:13e1a645978d8f0ac765f0174af7c6f9f9c5a0a93aecaa1e2ff056d43944a9ee"
  "sha256:3439edacc3cea422544688fb12c30c885991b59d7d83592a4e3f24ae41525b9c"
  "sha256:d0d27bb0cc61c85fff52ee33cd9ab54d85842051042a35b8c688fb48b6efba3f"
)

persist_path() {
  # Put swift on PATH for this and subsequent sessions.
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    if ! grep -qs "$SWIFT_ROOT/usr/bin" "$CLAUDE_ENV_FILE" 2>/dev/null; then
      echo "export PATH=\"$SWIFT_ROOT/usr/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
    fi
  fi
  ln -sf "$SWIFT_ROOT/usr/bin/swift"  /usr/local/bin/swift  2>/dev/null || true
  ln -sf "$SWIFT_ROOT/usr/bin/swiftc" /usr/local/bin/swiftc 2>/dev/null || true
}

# Idempotent: if a working toolchain is already present, just re-export PATH.
if [ -x "$SWIFT_BIN" ] && "$SWIFT_BIN" --version >/dev/null 2>&1; then
  persist_path
  echo "Swift already installed: $("$SWIFT_BIN" --version 2>&1 | head -1)" >&2
  exit 0
fi

echo "Installing Swift toolchain from official swift:6.1.2-noble image (via mirror.gcr.io)..." >&2

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$SWIFT_ROOT"

i=0
for d in "${LAYERS[@]}"; do
  i=$((i + 1))
  out="$TMP/layer$i.tar.gz"
  ok=""
  for attempt in 1 2 3 4; do
    if curl -fsSL --max-time 600 "$REGISTRY/$d" -o "$out"; then ok=1; break; fi
    echo "  layer $i download failed (attempt $attempt); retrying..." >&2
    sleep $((attempt * 3))
  done
  [ -n "$ok" ] || { echo "ERROR: could not download layer $i" >&2; exit 1; }
  # Layers are gzipped tarballs; tolerate benign pax/whiteout warnings, the
  # final --version check is the real gate.
  tar -xzf "$out" -C "$SWIFT_ROOT" || true
  rm -f "$out"
done

persist_path

if "$SWIFT_BIN" --version >/dev/null 2>&1; then
  echo "Swift installed: $("$SWIFT_BIN" --version 2>&1 | head -1)" >&2
else
  echo "ERROR: Swift install verification failed" >&2
  exit 1
fi

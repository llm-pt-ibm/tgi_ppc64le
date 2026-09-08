#!/usr/bin/env bash
set -euo pipefail

TGI_DIR="${1:-$HOME/lucas/text-generation-inference}"

[ -d "$TGI_DIR" ] || { echo "ERROR: directory not found: $TGI_DIR"; exit 1; }

cd "$TGI_DIR"

echo "Removing manual build backups..."
rm -f rust-toolchain.toml.bak \
      router/Cargo.toml.bak \
      router/src/server.rs.bak \
      backends/v2/Cargo.toml.bak \
      backends/v3/Cargo.toml.bak \
      server/pyproject.toml.bak \
      server/requirements_gen.txt.bak \
      server/text_generation_server/utils/kernels.py.bak \
      server/text_generation_server/layers/layernorm.py.bak

echo "Removing leftovers from failed builds..."
rm -rf './[178' rfc3161-client

echo "Repository status:"
git status --short

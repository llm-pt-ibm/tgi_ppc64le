#!/usr/bin/env bash
set -euo pipefail

TGI_REF="${TGI_REF:-main}"
CUDA_HOME_HOST="${CUDA_HOME_HOST:-/usr/local/cuda}"

if [ ! -d package ]; then
    echo "ERROR: package/ not found. It must contain:"
    echo "  torch-*-cp311-cp311-linux_ppc64le.tar.gz"
    echo "  numpy-*-cp311-cp311-linux_ppc64le.whl"
    echo "  hf_xet-*-abi3-manylinux_2_28_ppc64le.whl  (optional)"
    exit 1
fi

ls package/torch-*.tar.gz >/dev/null 2>&1 || { echo "ERROR: missing torch tarball in package/"; exit 1; }
ls package/numpy-*.whl    >/dev/null 2>&1 || { echo "ERROR: missing numpy wheel in package/"; exit 1; }

[ -d "$CUDA_HOME_HOST" ] || { echo "ERROR: CUDA not found at $CUDA_HOME_HOST"; exit 1; }

echo "==> [1/3] base (gcc-toolset-11, rust 1.88, protoc, libclang, conda)"
podman build --format docker -t tgi-ppc64le:base -f Dockerfile.base .

echo "==> [2/3] pytorch (openblas + local torch)"
podman build --format docker \
    --volume "${CUDA_HOME_HOST}:/usr/local/cuda:ro" \
    -t tgi-ppc64le:pytorch -f Dockerfile.pytorch .

echo "==> [3/3] tgi (ppc64le patches + rust/python build)"
podman build --format docker \
    --build-arg TGI_REF="${TGI_REF}" \
    --volume "${CUDA_HOME_HOST}:/usr/local/cuda:ro" \
    -t tgi-ppc64le:latest -f Dockerfile.tgi .

echo
echo "Build complete: tgi-ppc64le:latest"
echo "Run with: bash run.sh <local-path|org/model>"

#!/usr/bin/env bash
set -e

export PATH=/opt/conda/envs/tgi/bin:/opt/cargo/bin:/usr/local/cuda/bin:$PATH
export CUDACXX=/usr/local/cuda/bin/nvcc
export LD_LIBRARY_PATH=/opt/conda/envs/tgi/lib:/usr/local/cuda/lib64:/usr/lib64:${LD_LIBRARY_PATH:-}
export LD_PRELOAD=/opt/conda/envs/tgi/lib/libopenblas.so

# transformers calls from_pretrained with tp_plan='auto' and initializes
# torch.distributed; without these it fails with KeyError: 'LOCAL_RANK'
export LOCAL_RANK=${LOCAL_RANK:-0}
export RANK=${RANK:-0}
export WORLD_SIZE=${WORLD_SIZE:-1}
export MASTER_ADDR=${MASTER_ADDR:-localhost}
export MASTER_PORT=${MASTER_PORT:-29500}

python -c "import torch; print('CUDA available:', torch.cuda.is_available())" || true

if [ -n "${NUM_SHARD:-}" ]; then
    set -- "$@" --num-shard "${NUM_SHARD}"
fi

exec text-generation-launcher "$@"

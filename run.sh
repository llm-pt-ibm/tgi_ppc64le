#!/usr/bin/env bash
set -euo pipefail

MODEL_PATH="${1:-}"
PORT="${2:-8080}"
NUM_SHARD="${3:-1}"
IMAGE="${4:-tgi-ppc64le:latest}"

# max_batch_prefill_tokens must be >= max_input_tokens or the webserver
# aborts with ArgumentValidation
MAX_INPUT_TOKENS="${MAX_INPUT_TOKENS:-1024}"
MAX_TOTAL_TOKENS="${MAX_TOTAL_TOKENS:-2048}"
MAX_BATCH_PREFILL_TOKENS="${MAX_BATCH_PREFILL_TOKENS:-$MAX_INPUT_TOKENS}"

if [ -z "$MODEL_PATH" ]; then
    echo "Usage: bash run.sh <local-path|org/model> [port] [num_shard] [image]"
    echo
    echo "Examples:"
    echo "  bash run.sh /home/user/models/llama-3-8b"
    echo "  bash run.sh hf-internal-testing/tiny-random-gpt2"
    echo "  bash run.sh hf-internal-testing/tiny-random-gpt2 8081"
    echo
    echo "Optional variables:"
    echo "  MAX_INPUT_TOKENS, MAX_TOTAL_TOKENS, MAX_BATCH_PREFILL_TOKENS"
    exit 1
fi

if ss -tln 2>/dev/null | grep -q ":${PORT} "; then
    echo "ERROR: port $PORT is already in use."
    echo "Free it or pick another: bash run.sh <model> <port>"
    exit 1
fi

# The container ships the CUDA Toolkit; the driver comes from the host
DRIVER_MOUNTS=""
for lib in $(find /usr/lib64 -maxdepth 1 \( -name "libcuda.so*" -o -name "libnvidia-ml.so*" \) 2>/dev/null); do
    DRIVER_MOUNTS="$DRIVER_MOUNTS --volume $lib:$lib:ro"
done

GPU_DEVICES=""
for dev in /dev/nvidia*; do
    [ -e "$dev" ] && GPU_DEVICES="$GPU_DEVICES --device $dev"
done

if [ -z "$GPU_DEVICES" ]; then
    echo "WARNING: no /dev/nvidia* found. The server will run on CPU."
fi

# Accepts either a local path or a Hub model id (org/name)
if [ -d "$MODEL_PATH" ]; then
    MODEL_MOUNT="--volume $MODEL_PATH:/data:ro"
    MODEL_ARG="/data"
    OFFLINE="-e HF_HUB_OFFLINE=1"
    echo "Local model: $MODEL_PATH"
else
    MODEL_MOUNT=""
    MODEL_ARG="$MODEL_PATH"
    OFFLINE=""
    echo "Hub model: $MODEL_PATH"
fi

HF_CACHE="${HF_HOME:-$HOME/.cache/huggingface}"
mkdir -p "$HF_CACHE"

echo "Port: $PORT | Shards: $NUM_SHARD | Image: $IMAGE"
echo "Tokens: input=$MAX_INPUT_TOKENS total=$MAX_TOTAL_TOKENS prefill=$MAX_BATCH_PREFILL_TOKENS"

podman run --rm -it \
    --security-opt label=disable \
    --shm-size=32g \
    $GPU_DEVICES \
    $DRIVER_MOUNTS \
    --volume /usr/local/cuda:/usr/local/cuda:ro \
    --volume "$HF_CACHE":/root/.cache/huggingface \
    $MODEL_MOUNT \
    -p "${PORT}":8080 \
    -e NUM_SHARD="$NUM_SHARD" \
    $OFFLINE \
    "$IMAGE" \
    --model-id "$MODEL_ARG" --port 8080 \
    --max-input-tokens "$MAX_INPUT_TOKENS" \
    --max-total-tokens "$MAX_TOTAL_TOKENS" \
    --max-batch-prefill-tokens "$MAX_BATCH_PREFILL_TOKENS"

# Text Generation Inference on IBM Power9 (ppc64le)

Containerized build of Hugging Face's [Text Generation Inference](https://github.com/huggingface/text-generation-inference)
for IBM Power9 servers running AlmaLinux 8. Upstream publishes images for amd64
and ROCm only, so this repository builds TGI from source with the patches needed
for ppc64le.

The container ships the CUDA Toolkit and all build dependencies. The NVIDIA
driver and devices come from the host at runtime.

## Setup

Place the prebuilt artifacts in `package/`:

```
package/
├── torch-2.7.0a0-cp311-cp311-linux_ppc64le.tar.gz
├── numpy-1.26.4-cp311-cp311-linux_ppc64le.whl
└── hf_xet-1.1.0-cp37-abi3-manylinux_2_28_ppc64le.whl 
```

The `hf_xet` wheel is optional. If absent, it is compiled from source during the
build, which adds a few minutes.

## Build

```bash
bash build.sh
```

Three images are built in sequence:

| Image | Contents |
|---|---|
| `tgi-ppc64le:base` | gcc-toolset-11, Rust 1.88, protoc, libclang, conda |
| `tgi-ppc64le:pytorch` | OpenBLAS and the local PyTorch build |
| `tgi-ppc64le:latest` | TGI with ppc64le patches, Rust and Python components |

Override the TGI revision or the host CUDA path with environment variables:

```bash
TGI_REF=v3.3.1 CUDA_HOME_HOST=/usr/local/cuda-12.2 bash build.sh
```

## Run

```bash
bash run.sh <local-path|org/model> [port] [num_shard] [image]
```

Examples:

```bash
bash run.sh /home/user/models/llama-3-8b
bash run.sh hf-internal-testing/tiny-random-gpt2
bash run.sh hf-internal-testing/tiny-random-gpt2 8081
```

A local path is mounted read-only and the server runs offline. A Hub model id is
downloaded into the host cache at `~/.cache/huggingface`, which is bind-mounted
into the container.

Token limits can be adjusted without editing the script:

```bash
MAX_INPUT_TOKENS=4096 MAX_TOTAL_TOKENS=8192 bash run.sh /home/user/models/llama-3-8b
```

Note that `MAX_BATCH_PREFILL_TOKENS` defaults to `MAX_INPUT_TOKENS`; setting it
lower makes the webserver abort with `ArgumentValidation`. Also make sure
`MAX_TOTAL_TOKENS` does not exceed the model's context length, or CUDA raises a
device-side assert during warmup.

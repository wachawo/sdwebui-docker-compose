# Stable Diffusion WebUI (Docker + NVIDIA GPU)

Dockerized [AUTOMATIC1111/stable-diffusion-webui](https://github.com/AUTOMATIC1111/stable-diffusion-webui) based on `nvidia/cuda:13.0.3-cudnn-runtime-ubuntu24.04` with PyTorch cu130. A cu124 variant is also shipped.

## Requirements

- Linux with NVIDIA driver (check with `nvidia-smi`)
- Docker + Docker Compose
- [nvidia-container-toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) for GPU passthrough

### Install NVIDIA Container Toolkit (Ubuntu/Debian)

Without this package `docker compose up` fails with:
`Error response from daemon: could not select device driver "nvidia" with capabilities: [[gpu]]`.

```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

Verify:

```bash
docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu22.04 nvidia-smi
```

## Run

```bash
cp .env.example .env
docker compose up -d --build
```

Two build targets are shipped:

| Dockerfile         | Base                                           | Python | PyTorch | Host driver reports |
|--------------------|------------------------------------------------|--------|---------|---------------------|
| `Dockerfile`       | `nvidia/cuda:13.0.3-…-ubuntu24.04` *(default)* | 3.12   | cu130   | CUDA ≥ 13.0         |
| `Dockerfile.cu124` | `nvidia/cuda:12.4.1-…-ubuntu22.04`             | 3.10   | cu124   | CUDA 12.4 – 12.9    |

sdwebui's reference Python is 3.10. Recent revisions run on 3.12, but if you hit a Python-3.12 compat issue with the default image, switch to the cu124 variant in `.env`:

```env
DOCKERFILE=Dockerfile.cu124
SDWEBUI_IMAGE=sdwebui_gpu_cu124
```

Then rebuild: `docker compose build --no-cache && docker compose up -d`.

The UI is available at `http://localhost:7860`.

**First run is slow** (5–15 min): `launch.py` clones sub-repos (k-diffusion, BLIP, CodeFormer, …) into `./repositories` and pip-installs their requirements. The volume persists, so subsequent starts are fast.

Logs:

```bash
docker compose logs -f sdwebui
```

Stop:

```bash
docker compose down
```

## Configuration

Variables in `.env`:

| Variable             | Default          | Description                                                              |
|----------------------|------------------|--------------------------------------------------------------------------|
| `TZ`                 | `America/New_York` | Container timezone                                                     |
| `SDWEBUI_HOST`       | `0.0.0.0`        | Listen address                                                           |
| `SDWEBUI_PORT`       | `7860`           | sdwebui port                                                             |
| `SDWEBUI_EXTRA_ARGS` | `""`             | Extra `launch.py` flags (`--medvram`, `--lowvram`, `--no-half`, `--enable-insecure-extension-access`, `--xformers`) |
| `XFORMERS_PACKAGE`   | `""`             | Override xformers pin (only if `--xformers` is set). sdwebui's default `0.0.23.post1` is built for torch 2.1.2+cu121 and mismatches our torch 2.6+/2.10+. |
| `CIVITAI_TOKEN`      | `""`             | [Civitai API key](https://civitai.com/user/account) for model downloads  |
| `HF_TOKEN`           | `""`             | [HuggingFace token](https://huggingface.co/settings/tokens); also exported as `HUGGING_FACE_HUB_TOKEN` |
| `HF_HUB_OFFLINE`     | `0`              | `1` disables HF network (use only cached models)                         |
| `HUGGINGFACE_HUB_CACHE` | `/opt/stable-diffusion-webui/cache` | HF cache dir inside container (mounted from `./cache`)        |

## Volumes

Host directories are mounted into the container (created automatically):

| Host             | Container                                       | Purpose                              |
|------------------|-------------------------------------------------|--------------------------------------|
| `./models`       | `/opt/stable-diffusion-webui/models`            | Checkpoints, Lora, VAE, etc.         |
| `./extensions`   | `/opt/stable-diffusion-webui/extensions`        | Installed extensions                 |
| `./embeddings`   | `/opt/stable-diffusion-webui/embeddings`        | Textual inversion embeddings         |
| `./outputs`      | `/opt/stable-diffusion-webui/outputs`           | Generated images                     |
| `./repositories` | `/opt/stable-diffusion-webui/repositories`      | Sub-repos cloned by `launch.py`      |
| `./log`          | `/opt/stable-diffusion-webui/log`               | Logs                                 |
| `./cache`        | `/opt/stable-diffusion-webui/cache`             | HuggingFace hub cache                |

Drop checkpoints into `./models/Stable-diffusion/`, Lora into `./models/Lora/`, VAE into `./models/VAE/`, etc. Click **Refresh** in the UI to pick them up.

## Troubleshooting

### `fatal: could not read Username for 'https://github.com'` on first launch

`launch.py` clones sub-repos into `./repositories/` on first run. The upstream `Stability-AI/stablediffusion` repo was **deleted in late 2025**, and git reports a 401 auth challenge for a missing repo — which surfaces as a Username prompt and immediate failure (no TTY in the container). This compose file defaults `STABLE_DIFFUSION_REPO` to the community-maintained `w-e-w/stablediffusion` fork ([same commit hash sdwebui expects](https://github.com/AUTOMATIC1111/stable-diffusion-webui/issues/17204)). If you already hit the error before this was set, clean up the stale dir and restart:

```bash
sudo rm -rf ./repositories/stable-diffusion-stability-ai
docker compose down
docker compose up -d
docker compose logs -f sdwebui
```

No image rebuild is needed — the fix is purely via env vars.

## Install Without Docker

See [INSTALL.md](INSTALL.md).

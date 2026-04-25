# Installing stable-diffusion-webui on Ubuntu 22.04 with NVIDIA GPU

## 1. Check the NVIDIA Driver

```bash
nvidia-smi
```

If the command does not work, install the driver:

```bash
sudo ubuntu-drivers autoinstall
sudo reboot
```

After rebooting, run `nvidia-smi` again and note the CUDA version shown in the top-right corner of the output.

## 2. Install System Dependencies

sdwebui's reference Python is 3.10, which Ubuntu 22.04 ships by default.

```bash
sudo apt update
sudo apt install -y python3 python3-pip python3-venv git wget \
                    libgl1 libglib2.0-0 libsndfile1 ffmpeg
```

Check the version:

```bash
python3 --version   # expected: 3.10.x
```

## 3. Clone the Repository

```bash
mkdir -p ~/sdwebui-workspace
cd ~/sdwebui-workspace
git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git
cd stable-diffusion-webui
```

## 4. First Launch

`webui.sh` creates `venv/` automatically and installs everything on first run:

```bash
./webui.sh --listen --port 7860 --api --xformers
```

The first run takes 5–15 minutes — it clones sub-repositories (`repositories/k-diffusion`, `repositories/BLIP`, `repositories/CodeFormer`, …) and installs Python dependencies into `venv/`.

By default, the UI listens on `http://localhost:7860`.

Useful flags:

```bash
./webui.sh --listen --port 7860                 # network access
./webui.sh --listen --port 7860 --api           # enable REST API
./webui.sh --xformers                            # faster attention
./webui.sh --medvram                             # 6–8 GB VRAM
./webui.sh --lowvram                             # < 6 GB VRAM
./webui.sh --no-half                             # GPUs without fp16 support
./webui.sh --enable-insecure-extension-access    # allow installing extensions over LAN
```

## 5. Install CUDA-enabled PyTorch (manual)

`webui.sh` installs the torch version pinned in `requirements_versions.txt` against the default index. To use a different CUDA build, override before launching:

```bash
source venv/bin/activate
pip uninstall -y torch torchvision torchaudio
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124
```

Verify that the GPU is visible:

```bash
python3 -c "import torch; print(torch.cuda.is_available(), torch.version.cuda, torch.cuda.get_device_name(0))"
```

Expected output: `True <cuda_version> <gpu_name>`.

## 6. Quick Start Script (Optional)

Create `~/sdwebui-workspace/start-sdwebui.sh`:

```bash
#!/bin/bash
cd ~/sdwebui-workspace/stable-diffusion-webui
./webui.sh --listen --port 7860 --api --xformers
```

```bash
chmod +x ~/sdwebui-workspace/start-sdwebui.sh
```

## 7. Models

Place model files into the matching subdirectory of `stable-diffusion-webui/`:

| Type                | Path                               |
|---------------------|------------------------------------|
| Stable Diffusion checkpoints | `models/Stable-diffusion/` |
| Lora                | `models/Lora/`                     |
| VAE                 | `models/VAE/`                      |
| Embeddings          | `embeddings/`                      |
| Hypernetworks       | `models/hypernetworks/`            |
| ControlNet          | `models/ControlNet/` (with extension) |

After dropping a file in, click **Refresh** in the UI.

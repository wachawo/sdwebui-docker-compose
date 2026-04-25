# GPU image based on CUDA 13.0 + cuDNN (Ubuntu 24.04 ships Python 3.12).
# sdwebui's reference Python is 3.10; recent revisions run on 3.12, but if you
# hit a compat issue, fall back to Dockerfile.cu124 (Ubuntu 22.04 / Python 3.10).
FROM nvidia/cuda:13.0.3-cudnn-runtime-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# System dependencies for sdwebui runtime: ffmpeg (video), libgl1/libglib2.0-0
# (OpenCV), libsndfile1 (soundfile). libcublas-13-0 provides cuBLAS / cuBLASLt
# runtime that torch cu130 calls into — the `-runtime` base image does not
# include it, without it the first matmul on CUDA fails with
# `CUBLAS_STATUS_NOT_INITIALIZED`.
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 \
        python3-dev \
        python3-pip \
        python3-venv \
        git \
        ca-certificates \
        ffmpeg \
        build-essential \
        libgl1 \
        libglib2.0-0 \
        libsndfile1 \
        libcublas-13-0 \
    && rm -rf /var/lib/apt/lists/*

# Virtualenv on PATH means plain `pip`/`python3` target it without explicit
# activation.
ENV PATH="/opt/venv/bin:${PATH}"
RUN python3 -m venv /opt/venv \
 && pip install --no-cache-dir --upgrade pip

# Pin setuptools < 81 in pip's build-isolation envs. sdwebui's deps (openai
# CLIP, open_clip, etc.) import `pkg_resources` at build time; setuptools 81
# removed that module, causing `ModuleNotFoundError: No module named
# 'pkg_resources'` when pip builds those wheels.
RUN printf 'setuptools<81\n' > /opt/pip-constraints.txt
ENV PIP_CONSTRAINT=/opt/pip-constraints.txt

# sdwebui checkout. webui.sh is shell-driven and assumes interactive setup;
# in Docker we install requirements directly and let launch.py handle the
# remaining sub-repo cloning into /opt/stable-diffusion-webui/repositories
# at first run (that path is volume-mounted so it persists).
RUN git clone --depth=1 https://github.com/AUTOMATIC1111/stable-diffusion-webui.git /opt/stable-diffusion-webui

WORKDIR /opt/stable-diffusion-webui

# PyTorch with CUDA 13.0.
RUN pip install --no-cache-dir \
        --extra-index-url https://download.pytorch.org/whl/cu130 \
        torch==2.10.0+cu130 torchvision torchaudio==2.10.0+cu130

RUN pip install --no-cache-dir -r requirements_versions.txt

# Configure git to trust all repository directories (needed for volume-mounted repos
# from host, which may have ownership/permission differences in container context).
RUN git config --global --add safe.directory '*'

EXPOSE 7860

CMD ["python3", "launch.py", "--listen", "--port", "7860", "--api"]

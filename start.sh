#!/bin/bash
#
# Pod start script
# Downloads models from HF mirror on first run, then starts ComfyUI + Jupyter
#

set -e

COMFYUI_DIR=/workspace/ComfyUI
VENV_PYTHON="$COMFYUI_DIR/.venv/bin/python"
MIRROR="ReubenF10/ComfyUI-Models"

echo ""
echo "########################################"
echo "#        Wan 2.2 I2V - Starting       #"
echo "########################################"
echo ""

if [[ -z "$HF_TOKEN" ]]; then
    echo "ERROR: HF_TOKEN not set. Add it as a RunPod environment variable."
    exit 1
fi

export HF_TOKEN
export HF_HUB_ENABLE_HF_TRANSFER=1

# ── Download Models ──────────────────────────────────────────────
echo "  → Checking models..."

$VENV_PYTHON << PYEOF
import os, shutil
from huggingface_hub import hf_hub_download

token = os.environ["HF_TOKEN"]
mirror = "$MIRROR"
base = "$COMFYUI_DIR/models"

models = [
    ("unet/Wan2.2-I2V-A14B-HighNoise-Q4_K_S.gguf",                                          "unet"),
    ("unet/Wan2.2-I2V-A14B-LowNoise-Q4_0.gguf",                                             "unet"),
    ("vae/Wan2.1_VAE.safetensors",                                                           "vae"),
    ("loras/Wan21_I2V_14B_lightx2v_cfg_step_distill_lora_rank64.safetensors",               "loras"),
    ("loras/wan2.2_i2v_A14b_high_noise_lora_rank64_lightx2v_4step_1022.safetensors",        "loras"),
    ("loras/wan2.2_i2v_A14b_low_noise_lora_rank64_lightx2v_4step_1022.safetensors",         "loras"),
    ("text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors",                                "text_encoders"),
]

for filename, dest_folder in models:
    save_name = filename.split("/")[-1]
    dest = os.path.join(base, dest_folder, save_name)

    if os.path.exists(dest):
        print(f"  ⏭  Already exists: {save_name}")
        continue

    os.makedirs(os.path.join(base, dest_folder), exist_ok=True)
    print(f"  → Downloading: {save_name}")
    path = hf_hub_download(
        repo_id=mirror,
        filename=filename,
        token=token,
        local_dir="/tmp/hf_dl",
        local_dir_use_symlinks=False
    )
    shutil.move(path, dest)
    print(f"  ✓ Saved: {save_name}")

print("")
print("✓ All models ready")
PYEOF

# ── Download Workflows ───────────────────────────────────────────
echo "  → Downloading workflows..."
mkdir -p "$COMFYUI_DIR/user/default/workflows"
curl -fsSL https://raw.githubusercontent.com/Reuben-Fernandes/ComfyUI-Workflows/main/Wan_2_2.json \
    -o "$COMFYUI_DIR/user/default/workflows/Wan_2_2.json" && echo "  ✓ Wan_2_2.json" || true

# ── Launch Jupyter Lab ───────────────────────────────────────────
echo "  → Starting Jupyter Lab on port 8888..."
jupyter lab \
    --ip=0.0.0.0 \
    --port=8888 \
    --no-browser \
    --allow-root \
    --NotebookApp.token='' \
    --NotebookApp.password='' \
    > /workspace/jupyter.log 2>&1 &

# ── Launch ComfyUI ───────────────────────────────────────────────
echo "  → Launching ComfyUI on port 8188..."
echo ""
exec $VENV_PYTHON "$COMFYUI_DIR/main.py" \
    --listen 0.0.0.0 \
    --port 8188 \
    --use-sage-attention

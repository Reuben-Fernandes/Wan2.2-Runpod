#!/bin/bash
#
# Pod start script — runs on every launch
# Models downloaded via hf_transfer, everything else already baked in
#

set -e

COMFYUI_DIR=/workspace/ComfyUI
VENV_PYTHON="$COMFYUI_DIR/.venv/bin/python"
VENV_PIP="$COMFYUI_DIR/.venv/bin/pip"
MIRROR="ReubenF10/ComfyUI-Models"

echo ""
echo "########################################"
echo "#        Wan 2.2 I2V - Starting       #"
echo "########################################"
echo ""

if [[ -z "$HF_TOKEN" ]]; then
    echo "ERROR: HF_TOKEN not set. Set it as a RunPod environment variable."
    exit 1
fi

export HF_TOKEN
export HF_HUB_ENABLE_HF_TRANSFER=1

# ── Update ComfyUI and nodes ─────────────────────────────────────
echo "  → Updating ComfyUI..."
(cd "$COMFYUI_DIR" && git pull --quiet)

echo "  → Updating custom nodes..."
for dir in "$COMFYUI_DIR/custom_nodes/"/*/; do
    (cd "$dir" && git pull --quiet) 2>/dev/null || true
done

# ── Download Models ──────────────────────────────────────────────
echo ""
echo "  → Downloading models via hf_transfer..."

$VENV_PYTHON << EOF
import os, shutil
from huggingface_hub import hf_hub_download

token = os.environ["HF_TOKEN"]
mirror = "$MIRROR"
base = "$COMFYUI_DIR/models"

models = [
    ("unet/Wan2.2-I2V-A14B-HighNoise-Q4_K_S.gguf",                           "unet"),
    ("unet/Wan2.2-I2V-A14B-LowNoise-Q4_0.gguf",                              "unet"),
    ("vae/Wan2.1_VAE.safetensors",                                            "vae"),
    ("loras/Wan21_I2V_14B_lightx2v_cfg_step_distill_lora_rank64.safetensors", "loras"),
    ("text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors",                 "text_encoders"),
]

for filename, dest_folder in models:
    save_name = filename.split("/")[-1]
    dest = os.path.join(base, dest_folder, save_name)

    if os.path.exists(dest):
        print(f"  ⏭  Already exists: {save_name}")
        continue

    os.makedirs(os.path.join(base, dest_folder), exist_ok=True)
    print(f"  → {save_name}")
    path = hf_hub_download(
        repo_id=mirror,
        filename=filename,
        token=token,
        local_dir=f"/tmp/hf_dl",
        local_dir_use_symlinks=False
    )
    shutil.move(path, dest)
    print(f"  ✓ Saved: {save_name}")

print("")
print("✓ All models ready")
EOF

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
echo ""
echo "  → Launching ComfyUI on port 8188..."
echo ""
exec $VENV_PYTHON "$COMFYUI_DIR/main.py" \
    --listen 0.0.0.0 \
    --port 8188

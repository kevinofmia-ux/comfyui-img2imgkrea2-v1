# clean base image containing only comfyui, comfy-cli and comfyui-manager
FROM runpod/worker-comfyui:5.10.0-base

# build-time tokens for gated downloads — never baked into final image.
# pass via: docker build --build-arg HF_TOKEN=$HF_TOKEN ...
ARG HF_TOKEN=""

# install custom nodes into comfyui
RUN git clone https://github.com/rgthree/rgthree-comfy /comfyui/custom_nodes/rgthree-comfy && cd /comfyui/custom_nodes/rgthree-comfy && (git checkout c5ffa43de4ddb17244626a65a30700a05dd6b67d 2>/dev/null || (git fetch origin c5ffa43de4ddb17244626a65a30700a05dd6b67d --depth=1 && git checkout c5ffa43de4ddb17244626a65a30700a05dd6b67d) || echo "WARN: commit c5ffa43de4ddb17244626a65a30700a05dd6b67d unreachable in https://github.com/rgthree/rgthree-comfy, falling back to default branch HEAD")
RUN comfy node install --exit-on-fail comfyui-impact-subpack@1.3.5 --mode remote || (echo "WARN: comfyui-impact-subpack@1.3.5 unavailable in registry, falling back to latest" >&2 && comfy node install --exit-on-fail comfyui-impact-subpack --mode remote)
RUN comfy node install --exit-on-fail comfyui-impact-pack@8.28.1 || (echo "WARN: comfyui-impact-pack@8.28.1 unavailable in registry, falling back to latest" >&2 && comfy node install --exit-on-fail comfyui-impact-pack)
# `comfy node install` pulls each node's Python deps into /comfyui/.venv, mais
# ComfyUI tourne réellement depuis /opt/venv sur cette image de base (voir web
# root dans les logs runtime) — les deux venvs divergent, donc cv2 (et le reste)
# manquaient au runtime alors qu'ils s'étaient bien installés au build. On les
# réinstalle explicitement dans le vrai venv d'exécution, à partir des
# requirements.txt propres à chaque package (pas de liste de deps à la main).
RUN /opt/venv/bin/pip install --no-cache-dir -r /comfyui/custom_nodes/comfyui-impact-pack/requirements.txt
RUN /opt/venv/bin/pip install --no-cache-dir -r /comfyui/custom_nodes/comfyui-impact-subpack/requirements.txt
# ComfyUI-ChromaGrade n'est plus disponible sur GitHub (repo introuvable) —
# embarqué directement depuis la copie locale de Kevin (custom_nodes/ à la
# racine de ce repo) au lieu d'un git clone externe cassé.
COPY custom_nodes/ComfyUI-ChromaGrade /comfyui/custom_nodes/ComfyUI-ChromaGrade

# download models into comfyui
RUN BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do HF_TOKEN=$HF_TOKEN comfy model download --url 'https://huggingface.co/Abiray/Krea-2-Turbo-FP8-NVFP4/resolve/main/krea2_turbo_nvfp4.safetensors' --relative-path models/diffusion_models --filename 'krea2_turbo_nvfp4.safetensors' && break; if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done
RUN BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do HF_TOKEN=$HF_TOKEN comfy model download --url 'https://huggingface.co/Kutches/Kr3a/resolve/main/qwen3vl_4b_fp8_scaled.safetensors' --relative-path models/text_encoders --filename 'qwen3vl_4b_fp8_scaled.safetensors' && break; if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done
# le générateur auto avait mis "models/Unknown" (dossier que ComfyUI ne scanne
# pas) — corrigé vers les vrais chemins attendus par SAMLoader et
# UltralyticsDetectorProvider (confirmés sur les repos ltdrdata/ComfyUI-Impact-Pack
# et ComfyUI-Impact-Subpack), sinon le FaceDetailer ne trouve ni SAM ni le
# détecteur de visage et la chaîne se termine sans image (COMPLETED mais
# output.images vide).
RUN BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do comfy model download --url 'https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth' --relative-path models/sams --filename 'sam_vit_b_01ec64.pth' && break; if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done
RUN BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do HF_TOKEN=$HF_TOKEN comfy model download --url 'https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt' --relative-path models/ultralytics/bbox --filename 'face_yolov8m.pt' && break; if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done
RUN BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do HF_TOKEN=$HF_TOKEN comfy model download --url 'https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors' --relative-path models/vae --filename 'wan_2.1_vae.safetensors' && break; if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done
RUN BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do HF_TOKEN=$HF_TOKEN comfy model download --url 'https://huggingface.co/ABDALLALSWAITI/Upscalers/resolve/main/photo/4xNomosWebPhoto_RealPLKSR.pth' --relative-path models/upscale_models --filename '4xNomosWebPhoto_RealPLKSR.pth' && break; if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done

# copy all input data (like images or videos) into comfyui (uncomment and adjust if needed)
# COPY input/ /comfyui/input/

# user-provided inputs override the auto-generated placeholders above.
RUN wget --progress=dot:giga -O '/comfyui/input/Z-Image-H_00622_.png' "https://cool-anteater-319.convex.cloud/api/storage/6a5541e1-86d9-451e-8e6d-2f7268e202fb"

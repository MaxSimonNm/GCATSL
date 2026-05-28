#!/usr/bin/env bash
set -euo pipefail

cd /home/nilesh/SL/GCATSL

RUN_ID="${1:-2026-05-25_full_600epoch_5fold}"
SESSION_NAME="${2:-gcatsl_full_600}"
RUN_DIR="/home/nilesh/SL/GCATSL/runs/${RUN_ID}"

mkdir -p "${RUN_DIR}" output

cat > "${RUN_DIR}/run_full_gcatsl.sh" <<'SH'
#!/usr/bin/env bash
set -uo pipefail

source /home/nilesh/miniconda3/etc/profile.d/conda.sh
conda activate gcatsl-tf1

cd /home/nilesh/SL/GCATSL

RUN_ID=2026-05-25_full_600epoch_5fold
RUN_DIR="/home/nilesh/SL/GCATSL/runs/${RUN_ID}"
mkdir -p "${RUN_DIR}" output

{
  echo "run_id=${RUN_ID}"
  echo "start_ist=$(TZ=Asia/Kolkata date --iso-8601=seconds)"
  echo "start_utc=$(date -u --iso-8601=seconds)"
  echo "host=$(hostname)"
  echo "pwd=$(pwd)"
  echo "git_head=$(git rev-parse HEAD 2>/dev/null || true)"
  echo "git_status_start"
  git status --short 2>/dev/null || true
  echo "git_status_end"
  echo "python=$(python --version 2>&1)"
  python -c 'import tensorflow as tf; print("tensorflow=" + tf.__version__); print("tf_gpu=" + str(tf.test.is_gpu_available()))'
  nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
} > "${RUN_DIR}/metadata.txt" 2>&1

cp output/log.txt "${RUN_DIR}/preexisting_output_log.txt" 2>/dev/null || true
rm -f output/log.txt output/test_result_*.txt

/usr/bin/time -v python source/main.py \
  --n_epoch 600 \
  --n_head 2 \
  --n_fold 5 \
  --n_node 6375 \
  --n_feature 3 \
  --learning_rate 0.005 \
  --weight_decay 0.0001 \
  --dropout 0.7 \
  --input_dir ./data/toy_examples/ \
  --output_dir ./output/ \
  --log_dir ./output/ \
  > "${RUN_DIR}/stdout.log" \
  2> "${RUN_DIR}/stderr_time.log"

STATUS=$?

{
  echo "exit_status=${STATUS}"
  echo "end_ist=$(TZ=Asia/Kolkata date --iso-8601=seconds)"
  echo "end_utc=$(date -u --iso-8601=seconds)"
  ls -lh output/log.txt output/test_result_*.txt 2>/dev/null || true
  nvidia-smi --query-gpu=name,driver_version,memory.used,memory.total --format=csv,noheader || true
} >> "${RUN_DIR}/metadata.txt" 2>&1

cp output/log.txt "${RUN_DIR}/gcatsl_output_log.txt" 2>/dev/null || true
exit "${STATUS}"
SH

chmod +x "${RUN_DIR}/run_full_gcatsl.sh"

if tmux has-session -t "${SESSION_NAME}" 2>/dev/null; then
  echo "session_exists=${SESSION_NAME}"
  tmux list-sessions | grep "${SESSION_NAME}" || true
  exit 0
fi

tmux new-session -d -s "${SESSION_NAME}" "${RUN_DIR}/run_full_gcatsl.sh"
echo "started_session=${SESSION_NAME}"
echo "run_dir=${RUN_DIR}"
tmux list-sessions | grep "${SESSION_NAME}" || true

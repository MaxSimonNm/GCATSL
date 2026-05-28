#!/usr/bin/env bash
set -euo pipefail

RUN_DIR="/home/nilesh/SL/GCATSL/runs/2026-05-25_full_600epoch_5fold"
SESSION_NAME="gcatsl_full_600"
MONITOR_SESSION="gcatsl_full_600_monitor"

mkdir -p "${RUN_DIR}"

cat > "${RUN_DIR}/monitor.sh" <<'SH'
#!/usr/bin/env bash
set -u

RUN_DIR="/home/nilesh/SL/GCATSL/runs/2026-05-25_full_600epoch_5fold"

while tmux has-session -t gcatsl_full_600 2>/dev/null; do
  {
    echo "timestamp_ist=$(TZ=Asia/Kolkata date --iso-8601=seconds)"
    nvidia-smi --query-gpu=timestamp,name,utilization.gpu,memory.used,memory.total,power.draw,temperature.gpu --format=csv,noheader,nounits
    ps -eo pid,ppid,pcpu,pmem,rss,etime,cmd | grep "python source/main.py" | grep -v grep || true
    echo "---"
  } >> "${RUN_DIR}/resource_monitor.log" 2>&1
  sleep 60
done

{
  echo "monitor_end_ist=$(TZ=Asia/Kolkata date --iso-8601=seconds)"
  echo "main_session_finished"
} >> "${RUN_DIR}/resource_monitor.log" 2>&1
SH

chmod +x "${RUN_DIR}/monitor.sh"

if tmux has-session -t "${MONITOR_SESSION}" 2>/dev/null; then
  echo "session_exists=${MONITOR_SESSION}"
else
  tmux new-session -d -s "${MONITOR_SESSION}" "${RUN_DIR}/monitor.sh"
  echo "started_session=${MONITOR_SESSION}"
fi

tmux list-sessions | grep "${SESSION_NAME}" || true

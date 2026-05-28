from pathlib import Path

run_dir = Path("/home/nilesh/SL/GCATSL/runs/2026-05-25_full_600epoch_5fold")
monitor_path = run_dir / "resource_monitor.log"

max_mem = 0
max_util = 0
max_temp = 0
max_power = 0.0
samples = 0
first_ts = None
last_ts = None

for line in monitor_path.read_text().splitlines():
    if line.startswith("timestamp_ist="):
        ts = line.split("=", 1)[1]
        first_ts = first_ts or ts
        last_ts = ts
    if "Tesla T4" not in line or "," not in line:
        continue
    parts = [part.strip() for part in line.split(",")]
    try:
        util = int(parts[2])
        mem = int(parts[3])
        power = float(parts[5])
        temp = int(parts[6])
    except (IndexError, ValueError):
        continue
    samples += 1
    max_util = max(max_util, util)
    max_mem = max(max_mem, mem)
    max_power = max(max_power, power)
    max_temp = max(max_temp, temp)

print(f"samples={samples}")
print(f"first_monitor_ist={first_ts}")
print(f"last_monitor_ist={last_ts}")
print(f"max_gpu_util_percent={max_util}")
print(f"max_gpu_mem_mib={max_mem}")
print(f"max_power_w={max_power}")
print(f"max_temp_c={max_temp}")

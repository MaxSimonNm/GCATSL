# GCATSL Work Log

Date: 2026-05-25

## Scope

Initial work focuses on Goal 1: determine how to run GCATSL on the Ubuntu GPU VM.

## Actions

- Confirmed `G:\4bc_Projects\GCATSL` was empty and not a Git worktree.
- Cloned `https://github.com/lichenbiostat/GCATSL.git` into `G:\4bc_Projects\GCATSL`.
- Inspected `README.md`, `data/readme.md`, `source/main.py`, `source/train.py`, `source/dataprocessor.py`, `source/inits.py`, `source/models/gat.py`, `source/utils/layers.py`, and `source/metrics.py`.
- Confirmed the codebase is TensorFlow 1 graph-mode code with legacy package pins.
- Confirmed local Windows environment does not have `7z` or `unrar` available, so RAR extraction should be done on the Ubuntu VM with `unrar`.
- Added `requirements-tf1-gpu.txt` for the pinned Python package set.
- Added `docs/GCATSL_VM_RUNBOOK.md`.
- Patched run-blocking argparse name mismatches in `source/dataprocessor.py`.
- Patched the hard-coded three-feature interaction list in `source/inits.py`.
- Connected to the VM through `gcloud compute ssh ... --tunnel-through-iap --command`.
- Created isolated conda environment `gcatsl-tf1`.
- Installed CUDA 10.0 and cuDNN 7.6.5 user-space libraries in the conda environment.
- Installed TensorFlow 1.13.1 GPU and pinned Python dependencies.
- Verified TensorFlow sees the Tesla T4 as `/device:GPU:0`.
- Installed `unrar` because existing `7z` could list but not extract the RAR5 archive.
- Extracted `interaction_global_0.txt` through `interaction_global_4.txt`.
- Ran one-fold, one-epoch smoke test successfully.
- Ran five-fold, one-epoch validation successfully.
- Launched the full 600-epoch, five-fold run inside detached tmux session `gcatsl_full_600`.
- Added detached monitor session `gcatsl_full_600_monitor` to record GPU, memory, and process status once per minute.

## Findings

- TensorFlow 1.13.1 GPU should not be paired directly with CUDA 12.2 user-space libraries.
- The VM's NVIDIA driver can remain in place; use conda-provided CUDA 10.0 and cuDNN 7.x libraries inside the GCATSL environment.
- The toy run requires extracting `data/toy_examples/global interaction matrix.rar` to obtain `interaction_global_0.txt` through `interaction_global_4.txt`.
- If those global interaction files are missing, the code attempts expensive dense random-walk generation.
- The verified VM environment is `/home/nilesh/miniconda3/envs/gcatsl-tf1`.
- Five-fold, one-epoch validation completed with exit status `0`, wall time `4:10.58`, and max RSS `8,142,216 KB`.
- The validation produced `output/log.txt` and `output/test_result_0.txt` through `output/test_result_4.txt`.
- Five-fold one-epoch metrics were AUC mean `0.567693`, AUC std `0.041937`, AUPR mean `0.567993`, AUPR std `0.045273`.
- Full-scale run directory: `/home/nilesh/SL/GCATSL/runs/2026-05-25_full_600epoch_5fold`.
- Full-scale run started at `2026-05-25T23:16:49+05:30`.
- Full-scale stdout path: `/home/nilesh/SL/GCATSL/runs/2026-05-25_full_600epoch_5fold/stdout.log`.
- Full-scale stderr and `/usr/bin/time -v` path: `/home/nilesh/SL/GCATSL/runs/2026-05-25_full_600epoch_5fold/stderr_time.log`.
- Full-scale metadata path: `/home/nilesh/SL/GCATSL/runs/2026-05-25_full_600epoch_5fold/metadata.txt`.
- Full-scale resource monitor path: `/home/nilesh/SL/GCATSL/runs/2026-05-25_full_600epoch_5fold/resource_monitor.log`.
- Initial monitor sample showed GPU utilization `70%`, GPU memory `14653 MiB / 15360 MiB`, and active process `python source/main.py ... --n_epoch 600 --n_fold 5`.
- Full-scale run completed with exit status `0` at `2026-05-26T00:31:14+05:30`.
- Full-scale wall time was `1:14:23`; max RSS was `8,209,136 KB`.
- Full-scale metrics were AUC mean `0.932105`, AUC std `0.001272`, AUPR mean `0.943790`, AUPR std `0.001405`.
- Per-fold metrics were: fold 1 AUC `0.932904`, AUPR `0.943948`; fold 2 AUC `0.930294`, AUPR `0.942178`; fold 3 AUC `0.930958`, AUPR `0.942509`; fold 4 AUC `0.932678`, AUPR `0.944191`; fold 5 AUC `0.933694`, AUPR `0.946124`.
- Output files were generated: `output/log.txt` and `output/test_result_0.txt` through `output/test_result_4.txt`.
- Resource monitor peak sample was GPU utilization `77%`, GPU memory `14653 MiB / 15360 MiB`, power `83.69 W`, and temperature `79 C`.

## Open Items

- After Goal 1 is confirmed, start Goal 2 patient-data mapping requirements in a separate document section or file.

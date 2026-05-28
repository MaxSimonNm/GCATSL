# GCATSL VM Runbook

Date: 2026-05-25

Target VM:

- Name: `fbc-vm-prod-cir-research-gpu-in-01`
- Zone: `asia-south1-a`
- OS image: `ubuntu-2204-jammy-v20251023`
- GPU: NVIDIA Tesla T4, 15 GB
- Driver observed: `535.309.01`
- CUDA reported by driver: `12.2`

## Current Priority

Goal 1 is to make the original GCATSL repository runnable on the VM and to document the exact operating path. Patient-data adaptation and integration with the other project are tracked as later goals.

## Repository Findings

GCATSL is a legacy TensorFlow 1 codebase. The README states these requirements:

- Python 3.7
- TensorFlow 1.13.1
- NumPy 1.16.2
- SciPy 1.4.1
- scikit-learn

The entrypoint is:

```bash
python source/main.py --help
```

The toy example run uses:

```bash
python source/main.py \
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
  --log_dir ./output/
```

Important runtime behavior:

- `adj.txt` contains known SL pairs as 1-based gene indexes plus label.
- `feature_1.txt`, `feature_2.txt`, ..., `feature_N.txt` are loaded as dense feature matrices.
- `test_arr_0.txt` through `test_arr_4.txt` are fold index files for the default five-fold run.
- `interaction_global_0.txt` through `interaction_global_4.txt` are required for practical runs. The toy data ships these inside `data/toy_examples/global interaction matrix.rar`.
- If global interaction files are missing, the code tries to compute them with random walk over a dense `6375 x 6375` matrix. That is expensive and was also broken by argument-name typos before the local patch.

## GPU Compatibility Decision

The VM driver is modern enough to run older CUDA user-space libraries. However, TensorFlow 1.13.1 GPU binaries were built for CUDA 10.0 and cuDNN 7.x, not CUDA 12.x. Do not try to make TensorFlow 1.13.1 use the VM's system CUDA 12.2 libraries directly.

Recommended path:

1. Keep the NVIDIA driver as-is.
2. Use a Python 3.7 conda environment.
3. Install CUDA 10.0 and cuDNN 7.x user-space libraries inside that conda environment.
4. Install the pinned Python packages from `requirements-tf1-gpu.txt`.

CPU-only fallback is possible by replacing `tensorflow-gpu==1.13.1` with `tensorflow==1.13.1`, but it may be slow because the model builds dense `n_node x n_node` arrays.

## VM Setup Commands

Run on the Ubuntu VM:

```bash
sudo apt-get update
sudo apt-get install -y git wget unrar
```

Install Miniconda if it is not already present:

```bash
wget -O ~/miniconda.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash ~/miniconda.sh -b -p ~/miniconda3
source ~/miniconda3/etc/profile.d/conda.sh
conda init bash
```

Create the GCATSL environment:

```bash
source ~/miniconda3/etc/profile.d/conda.sh
conda create -n gcatsl-tf1 python=3.7 -y
conda activate gcatsl-tf1
conda install -c conda-forge cudatoolkit=10.0 cudnn=7.6.5 -y
python -m pip install --upgrade "pip<24" "setuptools<60" wheel
python -m pip install -r requirements-tf1-gpu.txt
```

Check TensorFlow and GPU visibility:

```bash
python - <<'PY'
import tensorflow as tf
print("TensorFlow:", tf.__version__)
print("GPU available:", tf.test.is_gpu_available())
print("Local devices:")
from tensorflow.python.client import device_lib
for d in device_lib.list_local_devices():
    print(" ", d.name, d.device_type)
PY
```

Expected result:

- TensorFlow version: `1.13.1`
- At least one GPU device should be listed.

If TensorFlow imports but GPU is false, inspect CUDA library loading:

```bash
python - <<'PY'
import tensorflow as tf
from tensorflow.python.client import device_lib
print(device_lib.list_local_devices())
PY
```

Then confirm the conda environment libraries are first in the dynamic loader path:

```bash
echo "$CONDA_PREFIX"
ls "$CONDA_PREFIX/lib" | grep -E 'cudart|cudnn|cublas'
```

## Clone And Prepare Data

```bash
git clone https://github.com/lichenbiostat/GCATSL.git
cd GCATSL
```

If using the locally patched copy from this workspace, copy or pull these files too:

- `requirements-tf1-gpu.txt`
- `docs/GCATSL_VM_RUNBOOK.md`
- `source/dataprocessor.py`
- `source/inits.py`

Extract the precomputed global interaction matrices:

```bash
cd data/toy_examples
unrar x "global interaction matrix.rar"
cd ../..
ls data/toy_examples/interaction_global_*.txt
```

The last command should show five files:

- `interaction_global_0.txt`
- `interaction_global_1.txt`
- `interaction_global_2.txt`
- `interaction_global_3.txt`
- `interaction_global_4.txt`

## Smoke Test

Start with a short run before the full 600-epoch job:

```bash
mkdir -p output
python source/main.py \
  --n_epoch 1 \
  --n_head 2 \
  --n_fold 1 \
  --n_node 6375 \
  --n_feature 3 \
  --learning_rate 0.005 \
  --weight_decay 0.0001 \
  --dropout 0.7 \
  --input_dir ./data/toy_examples/ \
  --output_dir ./output/ \
  --log_dir ./output/
```

Expected outputs:

- `output/log.txt`
- `output/test_result_0.txt`

Confirmed on `fbc-vm-prod-cir-research-gpu-in-01` with `gcatsl-tf1`:

- TensorFlow version: `1.13.1`
- `tf.test.is_gpu_available()`: `True`
- TensorFlow device: `/device:GPU:0`, Tesla T4, compute capability 7.5
- One-fold, one-epoch smoke test: exit status `0`, wall time `0:55.34`, max RSS `7,941,860 KB`
- Five-fold, one-epoch validation: exit status `0`, wall time `4:10.58`, max RSS `8,142,216 KB`
- Five-fold one-epoch metrics: AUC mean `0.567693`, AUC std `0.041937`, AUPR mean `0.567993`, AUPR std `0.045273`
- Full 600-epoch, five-fold run launched in tmux session `gcatsl_full_600`.
- Full run logs are under `/home/nilesh/SL/GCATSL/runs/2026-05-25_full_600epoch_5fold`.
- Resource monitor session: `gcatsl_full_600_monitor`.
- Full 600-epoch, five-fold run completed with exit status `0`.
- Full run wall time: `1:14:23`.
- Full run max RSS: `8,209,136 KB`.
- Full run output files: `output/log.txt` and `output/test_result_0.txt` through `output/test_result_4.txt`.
- Full run metrics: AUC mean `0.932105`, AUC std `0.001272`, AUPR mean `0.943790`, AUPR std `0.001405`.
- Resource monitor peak sample: GPU utilization `77%`, GPU memory `14653 MiB / 15360 MiB`, power `83.69 W`, temperature `79 C`.

Useful monitoring commands:

```bash
tmux list-sessions
tail -f /home/nilesh/SL/GCATSL/runs/2026-05-25_full_600epoch_5fold/stdout.log
tail -f /home/nilesh/SL/GCATSL/runs/2026-05-25_full_600epoch_5fold/stderr_time.log
tail -f /home/nilesh/SL/GCATSL/runs/2026-05-25_full_600epoch_5fold/resource_monitor.log
nvidia-smi
```

If the smoke test completes, run the full toy configuration:

```bash
python source/main.py \
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
  --log_dir ./output/
```

Monitor GPU usage in another shell:

```bash
watch -n 2 nvidia-smi
```

## Known Local Patches

The local workspace includes two run-oriented fixes:

1. `source/dataprocessor.py`
   - Changed `args.n_folds` to `args.n_fold`.
   - Changed `args.n_nodes` to `args.n_node`.
   - Without this, generating missing fold/global files fails because the argparse names do not exist.

2. `source/inits.py`
   - Replaced hard-coded three-entry interaction lists with lists sized from `args.n_feature`.
   - The toy run still uses three features, but this avoids a mismatch if a future run changes `--n_feature`.

## Preliminary Data Requirements For Patient Use

This is not the active implementation goal yet, but the run path already reveals the minimum data contract:

- A fixed gene universe of size `n_node`.
- A stable mapping from gene identifiers to 1-based integer node IDs.
- `adj.txt` with rows: `gene1_index gene2_index label`.
- One or more feature matrices named `feature_1.txt`, `feature_2.txt`, etc.
- Every feature matrix must have exactly `n_node` rows and columns compatible with the model's expected feature graph representation.
- Test fold files `test_arr_*.txt`, or code-generated fold files after the argument-name patch.
- Global interaction matrices `interaction_global_*.txt`, either precomputed or generated from the training folds.

The original model predicts synthetic-lethality scores for gene pairs. It does not directly ingest VCF, BAM, expression count matrices, clinical tables, or patient IDs. Patient-specific use will require a preprocessing layer that maps patient molecular data onto the model's gene universe and decides which candidate gene pairs should be scored.

## Integration Notes Placeholder

For the other project, the clean integration point is likely a wrapper that:

1. Validates the required GCATSL input directory.
2. Runs `source/main.py` in the pinned `gcatsl-tf1` environment.
3. Reads `test_result_*.txt`.
4. Maps integer gene IDs back to gene symbols and patient/project IDs.
5. Stores scored candidate pairs in the other project's expected schema.

The exact adapter design should wait until the other project's data model and execution environment are inspected.

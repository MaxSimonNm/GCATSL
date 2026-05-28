# GCATSL 600-Epoch 5-Fold Run Explanation

Date: 2026-05-27

## Summary

We ran GCATSL with `600` training epochs across `5` cross-validation folds to verify that the repository can run correctly on the GPU VM and reproduce the benchmark-style experiment intended by the authors.

The run completed successfully on `fbc-vm-prod-cir-research-gpu-in-01`:

```text
Exit status: 0
Started: 2026-05-25 23:16:49 IST
Finished: 2026-05-26 00:31:14 IST
Wall time: 1:14:23
Max RAM RSS: 8,209,136 KB
```

Final benchmark metrics:

```text
Fold 1: AUC = 0.932904, AUPR = 0.943948
Fold 2: AUC = 0.930294, AUPR = 0.942178
Fold 3: AUC = 0.930958, AUPR = 0.942509
Fold 4: AUC = 0.932678, AUPR = 0.944191
Fold 5: AUC = 0.933694, AUPR = 0.946124

AUC mean  = 0.932105
AUC std   = 0.001272
AUPR mean = 0.943790
AUPR std  = 0.001405
```

## 1. Why We Did The 600-Epoch 5-Fold Run

We did this run to prove that GCATSL works end-to-end on our VM using the same style of benchmark run that the repository authors provided in their README.

Before this run, we had only established smaller facts:

- The VM was reachable through `gcloud compute ssh`.
- The Tesla T4 GPU was visible.
- TensorFlow `1.13.1` could detect `/device:GPU:0`.
- The code could start without import/runtime failures.
- A short one-epoch smoke test could complete.
- The example data and precomputed global interaction matrices could be loaded.

The full run established a stronger result:

- The legacy TensorFlow environment is stable for a real workload.
- All five cross-validation folds work.
- The full example data path is complete.
- The GPU has enough memory for the original model configuration.
- GCATSL produces all expected output files.
- The benchmark metrics are in the expected high-performing range.

This was not yet a patient-specific analysis. It was a reproducibility and readiness test.

The question we answered was:

```text
Can this old research code run on our VM and produce a credible benchmark result?
```

The answer is yes.

### ELI5

We first made sure the computer, software, and code could work together. Then we gave the model the same practice problem from the authors. It solved it well, so we know our setup works.

## 2. What 600 Epoch x 5 Fold Means

There are two concepts: epochs and folds.

An epoch is one full training pass through the training data for a fold.

If `n_epoch = 600`, the model repeatedly trains on the same training split 600 times. Early epochs are where the model starts learning broad patterns. Later epochs refine the internal gene representations and prediction scores.

A fold is one split in cross-validation.

In 5-fold cross-validation, the known synthetic-lethal gene pairs are divided into five groups. The model trains and tests five separate times:

```text
Fold 1: train on groups 2,3,4,5; test on group 1
Fold 2: train on groups 1,3,4,5; test on group 2
Fold 3: train on groups 1,2,4,5; test on group 3
Fold 4: train on groups 1,2,3,5; test on group 4
Fold 5: train on groups 1,2,3,4; test on group 5
```

So `600 epoch x 5 fold` means five independent training/evaluation runs:

```text
Train for 600 epochs on fold 1, then test.
Train for 600 epochs on fold 2, then test.
Train for 600 epochs on fold 3, then test.
Train for 600 epochs on fold 4, then test.
Train for 600 epochs on fold 5, then test.
```

## 3. What If We Used A Epoch x B Fold?

If we call the epoch count `A` and fold count `B`, then:

- Higher `A` means more training per fold.
- Lower `A` is faster but may under-train the model.
- Too high `A` can sometimes overfit.
- Higher `B` means more cross-validation splits.
- Lower `B` gives a less robust estimate of performance.
- Higher `B` gives a more robust estimate but costs more compute.

Examples:

```text
1 epoch x 1 fold
```

This is only a smoke test. It checks whether the code runs. It does not show real model quality.

```text
1 epoch x 5 fold
```

This checks whether all five folds work. It still does not show final performance.

```text
600 epoch x 1 fold
```

This trains seriously, but tests on only one split. It is useful but less reliable.

```text
600 epoch x 5 fold
```

This is the benchmark-style run used by the repository. It trains seriously and evaluates across all five splits.

```text
1000 epoch x 10 fold
```

This would be heavier and slower. More compute does not automatically mean better science.

### ELI5

Epochs are how many times the model studies. Folds are how many different exams it takes. `600 x 5` means it studied a lot and took five exams.

## 4. Did The Authors Do The Same Run?

Yes. The repository README gives the main usage command with:

```text
--n_epoch 600
--n_fold 5
--n_node 6375
--n_feature 3
```

The repository data README says the example input data is provided to reproduce the GCATSL results reported in the paper.

The GCATSL paper reports approximately:

```text
AUC  = 0.9375
AUPR = 0.9483
```

Our run produced:

```text
AUC  = 0.932105
AUPR = 0.943790
```

These are very similar. Our result is slightly lower:

```text
AUC difference  = 0.9375 - 0.932105 = 0.005395
AUPR difference = 0.9483 - 0.943790 = 0.004510
```

That is about half a percentage point. This kind of difference is expected in old neural-network research code because of:

- random initialization,
- random negative sampling,
- TensorFlow/GPU nondeterminism,
- package/runtime differences,
- exact data split handling,
- small implementation/runtime differences.

The important point is that we reproduced the same performance band. We did not get a weak result such as `AUC = 0.60`, which would suggest a broken setup.

### ELI5

The authors got about 94 out of 100. We got about 93 out of 100. That is close enough to say our setup is working.

## 5. How To Interpret The Run

This run means:

```text
We have a working GCATSL installation on the VM that can reproduce benchmark behavior on the provided SynLethDB-style data.
```

It does not mean:

```text
We can directly upload a patient VCF, BAM, expression matrix, or clinical report and get patient-specific synthetic-lethal targets.
```

GCATSL is not currently packaged as a clinical patient pipeline. It is a gene-pair scoring model. Its native inputs are:

```text
adj.txt
feature_1.txt
feature_2.txt
feature_3.txt
test_arr_*.txt
interaction_global_*.txt
```

The model learns general synthetic-lethality patterns from:

- known synthetic-lethal gene pairs,
- gene feature graphs,
- local SL graph context,
- global SL graph context.

It outputs scores for gene pairs. A higher score means the model thinks that pair is more likely to be synthetic lethal.

For the benchmark run, we can calculate AUC/AUPR because we have held-out known labels. For a real patient, we usually do not already know the answer. In that setting, the task changes from model evaluation to prioritization:

```text
Given this patient's altered genes, which synthetic-lethal partner genes should we prioritize?
```

### ELI5

The model guesses which pairs of genes are dangerous together. We proved it works on the practice book. A patient file is not in practice-book format yet, so we need a translator.

## 6. What AUC And AUPR Mean

AUC asks:

```text
If we randomly pick one true SL pair and one negative pair, how often does the model rank the true SL pair higher?
```

An AUC of `0.5` is random guessing. An AUC close to `1.0` is strong.

Our AUC mean was:

```text
0.932105
```

AUPR is especially useful when positives are rare. Synthetic lethality is a rare-event problem because only a small fraction of all possible gene pairs are known SL pairs.

AUPR asks:

```text
When the model ranks gene pairs highly, how concentrated are the true positives near the top?
```

Our AUPR mean was:

```text
0.943790
```

These metrics are strong for the benchmark dataset. They do not automatically prove clinical usefulness for a patient cohort.

### ELI5

AUC asks whether the model usually puts good answers above bad answers. AUPR asks whether the top answers are mostly good. Our benchmark scores were strong.

## 7. What GCATSL Learned

GCATSL treats genes as nodes in graphs.

In the benchmark dataset:

- There are `6375` genes.
- Known synthetic-lethal pairs form an SL graph.
- Feature graphs come from biological sources such as PPI and Gene Ontology context.
- The model learns numerical representations of genes.
- It uses those representations to predict or reconstruct an SL interaction matrix.

In practical terms, GCATSL learns that genes with similar biological context and similar graph neighborhoods may have predictable synthetic-lethal relationships.

The score is a model confidence score, not a direct experimental measurement.

### ELI5

The model looks at a big map of genes. It learns which genes are near similar things. Then it guesses which pairs might be synthetic lethal.

## 8. How This Moves Us Toward Patient-Specific Use

For a patient, we need a bridge between patient molecular data and GCATSL's gene-pair model.

Patient data may include:

- somatic mutation calls,
- copy-number alterations,
- expression values,
- fusion calls,
- cancer type,
- clinical annotations,
- drug/actionability annotations.

GCATSL does not directly consume those files. A patient-specific workflow should look like:

```text
Patient data
  -> identify altered, deficient, or actionable genes
  -> map those genes to GCATSL's 6375-gene universe
  -> generate candidate SL pairs involving those patient genes
  -> score or retrieve GCATSL predictions for those pairs
  -> prioritize targetable partner genes
  -> annotate evidence, drugs, cancer relevance, and safety
```

Example:

If a tumor has loss of function in gene `A`, we ask:

```text
Which gene B, if inhibited, may selectively harm cells already defective in A?
```

The candidate pairs are:

```text
A - B1
A - B2
A - B3
...
```

Then we rank the candidate partner genes.

However, a high GCATSL score alone is not enough for clinical interpretation. We also need to check:

- whether the patient alteration is real and relevant,
- whether the altered gene is in the GCATSL universe,
- whether the partner gene is expressed,
- whether the partner gene is druggable,
- whether a known drug or inhibitor exists,
- whether evidence exists in SynLethDB, DepMap, CRISPR screens, literature, or cancer-specific sources,
- whether the pair is relevant to the patient's cancer type,
- whether there are toxicity concerns.

### ELI5

For a patient, we first find the broken genes in the tumor. Then we ask GCATSL which other genes might be good targets. Then we check whether those answers make medical and biological sense.

## 9. Important Caution About Current Output Files

The benchmark output files are useful, but they should not be treated as a final patient report.

The current code writes benchmark cross-validation outputs. It was built for evaluating model performance, not for patient-facing reporting.

Before patient integration, we should create a deliberate prediction/export script that:

- accepts patient altered genes,
- maps them to node IDs,
- generates candidate gene pairs,
- scores or ranks pairs,
- outputs gene symbols and node IDs clearly,
- includes evidence and filtering metadata.

There is also a code path in `source/inits.py` that should be audited before relying on `test_result_*.txt` as a gene-pair interpretation table. The metrics are useful for benchmark validation, but patient reporting should use a cleaner, purpose-built export path.

### ELI5

The benchmark report proves the model works. It is not yet a patient report. We need to build a clean patient report generator.

## 10. What We Achieved Overall

We achieved four things:

1. Proved GCATSL runs on the Ubuntu Tesla T4 VM.
2. Reproduced a benchmark-style run, not just a startup test.
3. Produced metrics close to the authors' reported results.
4. Identified the key bridge needed for patient-specific use: gene mapping and patient-data preprocessing.

The next major task is to turn the recovered GCATSL gene universe into a patient-specific scoring workflow.

### ELI5

The machine works. The model works. The practice result looks right. Now we need to build the translator that lets a patient file talk to the model.

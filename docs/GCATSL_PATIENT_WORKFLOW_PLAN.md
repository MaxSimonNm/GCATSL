# GCATSL Patient-Specific Workflow Plan

Date: 2026-05-27

## Current State

The base GCATSL repository has been cloned and made runnable on the VM.

The full benchmark run completed successfully:

```text
600 epochs x 5 folds
AUC mean  = 0.932105
AUPR mean = 0.943790
```

The GCATSL node-ID-to-gene-symbol mapping has also been recovered:

```text
data/gene_mapping/gcatsl_node_gene_mapping.tsv
data/gene_mapping/gcatsl_sl_pairs_with_symbols.tsv
data/gene_mapping/mapping_validation_report.txt
```

This mapping is the required bridge between patient gene symbols and GCATSL's internal 1-based node IDs.

## Goal

Build a patient-specific synthetic-lethality prioritization workflow around GCATSL.

The workflow should answer:

```text
Given a patient's altered tumor genes, which synthetic-lethal partner genes should be prioritized, and why?
```

## Working Assumptions

- GCATSL remains a research model and is not used alone for clinical decision-making.
- Patient-specific output should be a prioritized research/actionability table, not a clinical recommendation.
- The first implementation should use a simple altered-gene list as input.
- More complex inputs such as VCF, CNV, expression, and fusion files can be added after the core scoring path works.
- Gene symbols should be normalized to a consistent HGNC-style namespace before mapping to GCATSL node IDs.

## Phase 1: Repository And GitHub Hygiene

Objective: make our work saveable and reviewable without pushing directly to the upstream repository.

Current local setup:

```text
upstream = https://github.com/lichenbiostat/GCATSL.git
origin   = https://github.com/MaxSimonNm/GCATSL.git
branch   = patient-workflow-foundation
```

As of 2026-05-28, the intended fork URL `https://github.com/MaxSimonNm/GCATSL` did not appear to exist publicly yet. Create the fork from the upstream repository first, then the local `origin` remote will point to the correct destination.

Tasks:

1. Create the GitHub fork under `MaxSimonNm`.
2. Review the working tree and decide what should be committed.
3. Add a `.gitignore` entry for large recovered/downloaded external files if needed.
4. Commit the environment, docs, scripts, mapping, and minimal source fixes.
5. Push the branch to the fork.

Suggested commands after the fork exists:

```bash
git add docs requirements-tf1-gpu.txt scripts source/dataprocessor.py source/inits.py data/gene_mapping
git commit -m "Document VM run and recover GCATSL gene mapping"
git push -u origin patient-workflow-foundation
```

Large downloaded external files under `external/` should be reviewed before committing. They may be better excluded or replaced with reproducible download/recovery instructions.

## Phase 2: Input Contract For Patient Data

Objective: define the first supported patient input format.

Recommended first input: a simple TSV file.

Example:

```text
patient_id	gene_symbol	alteration_type	evidence	source
P001	BRCA1	LOF	pathogenic frameshift	VCF
P001	PTEN	deletion	copy number loss	CNV
P001	TP53	LOF	pathogenic SNV	VCF
```

Required columns:

- `patient_id`
- `gene_symbol`
- `alteration_type`

Optional columns:

- `evidence`
- `source`
- `variant_id`
- `transcript`
- `protein_change`
- `copy_number`
- `expression_value`
- `cancer_type`

Deliverable:

```text
docs/patient_input_schema.md
```

## Phase 3: Patient Gene Mapping Checker

Objective: map patient genes to the GCATSL 6375-gene universe.

Script:

```text
scripts/check_patient_genes.py
```

Inputs:

```text
patient altered-gene TSV
data/gene_mapping/gcatsl_node_gene_mapping.tsv
```

Outputs:

```text
patient_id
input_gene_symbol
normalized_gene_symbol
gcatsl_node_id
in_gcatsl_universe
notes
```

Purpose:

- Identify genes that GCATSL can score.
- Identify genes outside the GCATSL universe.
- Prevent silent dropping of patient genes.

## Phase 4: Candidate Pair Generation

Objective: generate candidate synthetic-lethal pairs for mapped patient genes.

For each altered patient gene `A`, generate pairs:

```text
A - B1
A - B2
A - B3
...
```

where `B` is each possible partner gene in the GCATSL universe.

The initial output should include:

```text
patient_id
altered_gene_symbol
altered_gene_node_id
candidate_partner_symbol
candidate_partner_node_id
pair_key
```

Optional filters:

- remove self-pairs,
- restrict to druggable genes,
- restrict to expressed genes if expression data is available,
- restrict to known cancer-relevant genes.

## Phase 5: Scoring Strategy

Objective: decide how to obtain GCATSL scores for patient candidate pairs.

There are two possible paths.

### Path A: Use Benchmark-Trained Outputs

This is faster but less clean. It depends on whether we can export or reconstruct the final score matrix from a trained fold/run.

Pros:

- Faster to prototype.
- Uses already-validated model behavior.

Cons:

- Current code does not save a reusable trained model checkpoint.
- Cross-validation outputs are for benchmark evaluation, not patient inference.
- Fold-specific models may give slightly different scores.

### Path B: Build A Dedicated Inference/Export Mode

This is the better engineering path.

Tasks:

1. Modify training code to save trained model checkpoints or final score matrices.
2. Add an inference script that loads model artifacts.
3. Export a full scored matrix or patient-specific candidate scores.
4. Include gene symbols in the output.

Recommended first deliverable:

```text
scripts/export_gcatsl_scores.py
```

Output:

```text
gene1_node_id
gene1_symbol
gene2_node_id
gene2_symbol
gcatsl_score
model_run_id
```

## Phase 6: Biological And Clinical Annotation

Objective: convert raw GCATSL scores into a useful prioritization table.

Potential annotation layers:

- known SL evidence from SynLethDB,
- DepMap/CRISPR dependency evidence,
- druggability,
- known inhibitors/drugs,
- cancer-type relevance,
- expression support,
- essentiality and toxicity concerns,
- literature evidence.

Patient-level output should eventually look like:

```text
patient_id
altered_gene
alteration_type
candidate_partner
gcatsl_score
rank
known_sl_evidence
drug_or_inhibitor
druggability_class
cancer_context
expression_support
notes
```

## Phase 7: Integration With The Other Project

Objective: connect GCATSL outputs to the other project's data model.

Before integration, inspect:

- how that project represents patients,
- how it stores variants/altered genes,
- whether it has a database schema,
- whether it expects CSV/TSV/JSON,
- where drug/actionability annotations live,
- whether it runs as CLI, web app, notebook, or pipeline.

Likely integration design:

```text
other project patient data
  -> GCATSL adapter input TSV
  -> patient gene mapping checker
  -> candidate pair generator
  -> GCATSL scorer/exporter
  -> annotation/prioritization table
  -> import back into other project
```

## Immediate Next Actions

1. Decide where the GitHub fork should live.
2. Cleanly set up remotes and branch.
3. Decide whether to commit `external/` files or replace them with reproducibility instructions.
4. Review `data/gene_mapping/` and commit it if acceptable.
5. Build `docs/patient_input_schema.md`.
6. Build `scripts/check_patient_genes.py`.
7. Test the checker on a small hand-written patient altered-gene TSV.
8. Decide score-export strategy: full matrix export, checkpoint-based inference, or patient-pair-only scoring.

## Key Risks

- The current benchmark code was not designed as a patient inference pipeline.
- GCATSL uses a fixed 6375-gene universe; genes outside that universe cannot be scored directly.
- Raw GCATSL scores are research predictions and need external evidence before interpretation.
- The current cross-validation output files should not be treated as final patient reports.
- Large external data files may not belong in Git history.

## Definition Of Done For The Next Milestone

The next milestone is complete when we can run:

```bash
python scripts/check_patient_genes.py \
  --patient_genes examples/patient_altered_genes.tsv \
  --mapping data/gene_mapping/gcatsl_node_gene_mapping.tsv \
  --output output/patient_gene_mapping_report.tsv
```

and receive:

- mapped genes,
- unmapped genes,
- clear warnings,
- no silent data loss,
- a documented patient input schema.

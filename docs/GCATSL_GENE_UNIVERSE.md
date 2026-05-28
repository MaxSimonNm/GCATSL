# GCATSL Gene Universe And Node Mapping

Date: 2026-05-27

## Summary

The GCATSL toy/SynLethDB benchmark uses a fixed gene universe of 6375 genes. The model input files use 1-based integer node IDs, not gene symbols.

The node-ID-to-gene-symbol mapping has been recovered from a historical file in the repository Git history:

- Source commit: `018932e`
- Source file: `data/Human_SL_SynLethDB.xlsx`
- Recovered local copy: `external/git_history_data/Human_SL_SynLethDB.xlsx`

Generated artifacts:

- `data/gene_mapping/gcatsl_node_gene_mapping.tsv`
- `data/gene_mapping/gcatsl_sl_pairs_with_symbols.tsv`
- `data/gene_mapping/mapping_validation_report.txt`

## Validation

The recovered spreadsheet has 19669 rows. The current model input `data/toy_examples/adj.txt` has 19668 rows.

The row order and direction are not identical throughout the two files, but the unordered gene-pair set is identical:

- Unordered pairs in recovered spreadsheet: `19668`
- Unordered pairs in `adj.txt`: `19668`
- Pair sets identical: `True`

The one-row difference in the spreadsheet comes from a duplicated unordered pair. After deduplication by unordered node pair, it matches `adj.txt` exactly.

The mapping itself is complete:

- Mapping rows: `6375`
- Minimum node ID: `1`
- Maximum node ID: `6375`
- Unique node IDs: `6375`
- Unique gene symbols: `6375`
- Missing node IDs: `0`
- Node ID conflicts: `0`
- Gene symbol conflicts: `0`

## Examples

First rows of the mapping:

```text
node_id  gene_symbol
1        A2M
2        A2ML1
3        AADAT
4        AAR2
5        AATF
```

The first rows of `adj.txt` become:

```text
gene1_node_id  gene1_symbol  gene2_node_id  gene2_symbol  label
1              A2M           2411           HRAS          1
1              A2M           2781           KRAS          1
1              A2M           3579           NRAS          1
2              A2ML1         2411           HRAS          1
2              A2ML1         2781           KRAS          1
2              A2ML1         3579           NRAS          1
```

## Regeneration

Run:

```bash
python scripts/build_gcatsl_gene_mapping.py
```

The script expects the recovered historical spreadsheet at:

```text
external/git_history_data/Human_SL_SynLethDB.xlsx
```

That file can be recovered from Git history with:

```bash
git show 018932e:data/Human_SL_SynLethDB.xlsx > external/git_history_data/Human_SL_SynLethDB.xlsx
```

On Windows PowerShell, use a binary-safe route for this command. A plain text pipe can corrupt the spreadsheet.

## Patient-Data Relevance

This mapping is the required bridge from patient-level gene symbols to GCATSL node IDs.

For a patient-specific workflow:

1. Normalize patient genes to HGNC symbols.
2. Join the patient genes to `gcatsl_node_gene_mapping.tsv`.
3. Genes absent from the 6375-gene universe cannot be scored directly by this GCATSL model.
4. For present genes, generate candidate pairs against the 6375-node universe.
5. Score/rank the candidate synthetic-lethal partners.

The next implementation step is to build a patient altered-gene list checker that reports which patient genes are inside or outside this GCATSL universe.

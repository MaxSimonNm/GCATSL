from pathlib import Path

import numpy as np
import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
SOURCE_XLSX = ROOT / "external" / "git_history_data" / "Human_SL_SynLethDB.xlsx"
ADJ_PATH = ROOT / "data" / "toy_examples" / "adj.txt"
OUT_DIR = ROOT / "data" / "gene_mapping"
MAPPING_PATH = OUT_DIR / "gcatsl_node_gene_mapping.tsv"
PAIRS_PATH = OUT_DIR / "gcatsl_sl_pairs_with_symbols.tsv"
REPORT_PATH = OUT_DIR / "mapping_validation_report.txt"


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    source = pd.read_excel(SOURCE_XLSX)
    adj = np.loadtxt(ADJ_PATH, dtype=int)

    mapping = pd.concat(
        [
            source[["Gene1_ID", "Gene1_name"]].rename(
                columns={"Gene1_ID": "node_id", "Gene1_name": "gene_symbol"}
            ),
            source[["Gene2_ID", "Gene2_name"]].rename(
                columns={"Gene2_ID": "node_id", "Gene2_name": "gene_symbol"}
            ),
        ],
        ignore_index=True,
    ).drop_duplicates()
    mapping["node_id"] = mapping["node_id"].astype(int)
    mapping = mapping.sort_values("node_id").reset_index(drop=True)

    if mapping["node_id"].nunique() != len(mapping):
        raise RuntimeError("Node ID conflicts detected in mapping")
    if mapping["gene_symbol"].nunique() != len(mapping):
        raise RuntimeError("Gene symbol conflicts detected in mapping")
    expected_ids = set(range(1, int(adj[:, :2].max()) + 1))
    missing_ids = expected_ids.difference(set(mapping["node_id"]))
    if missing_ids:
        raise RuntimeError(f"Missing node IDs: {sorted(missing_ids)[:20]}")

    id_to_symbol = dict(zip(mapping["node_id"], mapping["gene_symbol"]))
    pairs = pd.DataFrame(
        {
            "gene1_node_id": adj[:, 0].astype(int),
            "gene1_symbol": [id_to_symbol[int(x)] for x in adj[:, 0]],
            "gene2_node_id": adj[:, 1].astype(int),
            "gene2_symbol": [id_to_symbol[int(x)] for x in adj[:, 1]],
            "label": adj[:, 2].astype(int),
        }
    )

    source_pairs = {
        tuple(sorted((int(a), int(b))))
        for a, b in source[["Gene1_ID", "Gene2_ID"]].itertuples(index=False)
    }
    adj_pairs = {tuple(sorted((int(a), int(b)))) for a, b in adj[:, :2]}

    mapping.to_csv(MAPPING_PATH, sep="\t", index=False)
    pairs.to_csv(PAIRS_PATH, sep="\t", index=False)

    def rel(path: Path) -> str:
        return path.relative_to(ROOT).as_posix()

    report = [
        "GCATSL gene mapping validation",
        f"source_xlsx={rel(SOURCE_XLSX)}",
        f"adj_path={rel(ADJ_PATH)}",
        f"source_rows={len(source)}",
        f"adj_rows={len(adj)}",
        f"mapping_rows={len(mapping)}",
        f"min_node_id={mapping['node_id'].min()}",
        f"max_node_id={mapping['node_id'].max()}",
        f"unique_node_ids={mapping['node_id'].nunique()}",
        f"unique_gene_symbols={mapping['gene_symbol'].nunique()}",
        f"unordered_source_pairs={len(source_pairs)}",
        f"unordered_adj_pairs={len(adj_pairs)}",
        f"unordered_pair_sets_identical={source_pairs == adj_pairs}",
        f"mapping_path={rel(MAPPING_PATH)}",
        f"pairs_path={rel(PAIRS_PATH)}",
    ]
    REPORT_PATH.write_text("\n".join(report) + "\n", encoding="utf-8")
    print("\n".join(report))


if __name__ == "__main__":
    main()

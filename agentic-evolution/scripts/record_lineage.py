#!/usr/bin/env python3

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description="Append a lineage record.")
    parser.add_argument("--lineage-file", default="lineage.jsonl")
    parser.add_argument("--target-op", required=True)
    parser.add_argument("--decision", choices=["accepted", "rejected"], required=True)
    parser.add_argument("--summary", required=True)
    parser.add_argument("--files", nargs="*", default=[])
    parser.add_argument("--local-result", default="")
    parser.add_argument("--xla-result", default="")
    parser.add_argument("--whole-model-result", default="")
    args = parser.parse_args()

    record = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "target_op": args.target_op,
        "decision": args.decision,
        "summary": args.summary,
        "files": args.files,
        "local_result": args.local_result,
        "xla_result": args.xla_result,
        "whole_model_result": args.whole_model_result,
    }

    path = Path(args.lineage_file)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(record, ensure_ascii=True) + "\n")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description="Record an operator optimization iteration.")
    parser.add_argument("--out-file", default="memory/operator_lineage.jsonl")
    parser.add_argument("--semantic-op-id", required=True)
    parser.add_argument("--iteration-id", required=True)
    parser.add_argument("--decision", choices=["positive", "negative", "rejected"], required=True)
    parser.add_argument("--summary", required=True)
    parser.add_argument("--targeted-profile", default="")
    parser.add_argument("--full-profile", default="")
    parser.add_argument("--proposal", default="")
    parser.add_argument("--candidate", default="")
    args = parser.parse_args()

    record = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "semantic_op_id": args.semantic_op_id,
        "iteration_id": args.iteration_id,
        "decision": args.decision,
        "summary": args.summary,
        "targeted_profile": args.targeted_profile,
        "full_profile": args.full_profile,
        "proposal": args.proposal,
        "candidate": args.candidate,
    }

    path = Path(args.out_file)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as f:
      f.write(json.dumps(record, ensure_ascii=True) + "\n")


if __name__ == "__main__":
    main()

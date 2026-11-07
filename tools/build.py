#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
import sys

from ryostore_tools.catalogue import CatalogueError, build


REPO_ROOT = Path(__file__).resolve().parent.parent


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Validate catalogue items and write their manifest.json and the category registry.json.",
    )
    parser.add_argument("items", nargs="*", metavar="<category>/<id>", help="items to build; default: every item")
    parser.add_argument("--check", action="store_true", help="write nothing; fail when a generated file is stale")
    args = parser.parse_args(argv)
    try:
        written = build(REPO_ROOT, args.items, check=args.check)
    except CatalogueError as error:
        print(error, file=sys.stderr)
        return 1
    if args.check:
        print("catalogue is current")
    for path in written:
        print(f"wrote {path.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Check or apply the exact shared brain core from an upstream checkout.

Usage:
  python3 scripts/brain_core_sync.py --upstream /path/to/brain-template
  python3 scripts/brain_core_sync.py --upstream /path/to/brain-template --apply

Only paths declared in brain-core.json are compared or copied. Private overlay
files are never read, copied, or deleted. Apply aborts when a shared target path
already has uncommitted changes.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = "brain-core.json"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_manifest(root: Path) -> dict:
    path = root / MANIFEST
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise SystemExit(f"manifest not found: {path}") from exc
    paths = data.get("sharedPaths")
    if data.get("schemaVersion") != 1 or not isinstance(paths, list) or not paths:
        raise SystemExit(f"unsupported or empty manifest: {path}")
    for rel in paths:
        if not isinstance(rel, str) or not rel:
            raise SystemExit(f"unsafe shared path in manifest: {rel!r}")
        candidate = Path(rel)
        if candidate.is_absolute() or ".." in candidate.parts:
            raise SystemExit(f"unsafe shared path in manifest: {rel!r}")
    if len(paths) != len(set(paths)):
        raise SystemExit(f"duplicate shared path in manifest: {path}")
    return data


def dirty_shared_paths(root: Path, paths: list[str]) -> list[str]:
    if not (root / ".git").exists():
        return []
    proc = subprocess.run(
        ["git", "-C", str(root), "status", "--porcelain", "--", *paths],
        capture_output=True,
        text=True,
        check=True,
    )
    return [line[3:] for line in proc.stdout.splitlines() if line.strip()]


def compare(upstream: Path, target: Path, paths: list[str]) -> list[dict[str, str]]:
    drift = []
    for rel in paths:
        source = upstream / rel
        dest = target / rel
        if not source.is_file():
            drift.append({"path": rel, "status": "missing-upstream"})
        elif not dest.is_file():
            drift.append({"path": rel, "status": "missing-target"})
        elif digest(source) != digest(dest):
            drift.append({"path": rel, "status": "different"})
    return drift


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--upstream", required=True, type=Path, help="local OSS checkout")
    parser.add_argument("--target", type=Path, default=ROOT, help="workspace to check")
    parser.add_argument("--apply", action="store_true", help="copy drifted shared paths")
    parser.add_argument("--json", action="store_true", help="emit machine-readable result")
    args = parser.parse_args()

    upstream = args.upstream.expanduser().resolve()
    target = args.target.expanduser().resolve()
    upstream_manifest = load_manifest(upstream)
    target_manifest = load_manifest(target)
    paths = upstream_manifest["sharedPaths"]
    if paths != target_manifest.get("sharedPaths"):
        raise SystemExit("sharedPaths differs between upstream and target; review manifests manually")

    drift = compare(upstream, target, paths)
    applied: list[str] = []
    if args.apply and drift:
        missing_upstream = [item["path"] for item in drift if item["status"] == "missing-upstream"]
        if missing_upstream:
            raise SystemExit("upstream shared paths are missing; refusing partial apply: " + ", ".join(missing_upstream))
        dirty = dirty_shared_paths(target, paths)
        if dirty:
            raise SystemExit("shared target paths have uncommitted changes; refusing apply: " + ", ".join(dirty))
        for item in drift:
            rel = item["path"]
            source = upstream / rel
            dest = target / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, dest)
            applied.append(rel)
        drift = compare(upstream, target, paths)

    result = {"upstream": str(upstream), "target": str(target), "drift": drift, "applied": applied}
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    elif drift:
        for item in drift:
            print(f"{item['status']}: {item['path']}")
    else:
        suffix = f"; applied {len(applied)}" if applied else ""
        print(f"brain core in sync: {len(paths)} paths{suffix}")
    return 1 if drift else 0


if __name__ == "__main__":
    sys.exit(main())

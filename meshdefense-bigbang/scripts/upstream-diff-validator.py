#!/usr/bin/env python3
"""
MeshDefense Upstream Release Diff & Breaking Change Validation Utility
========================================================================
STORY 6.1: Upstream Release Diff & Breaking Change Validation Utility
DoD Impact Level 6 (IL6) & NIST 800-53 (CM-2, CM-3, SI-2) Compliant.

Capabilities:
  1. Compares currently running Big Bang release against target upstream releases.
  2. Extracts and tabulates chart and subchart version bumps across core packages.
  3. Parses breaking structural changes, CRD modifications, and values hierarchy shifts.
  4. Identifies component deprecations and retirement timelines (e.g., Gatekeeper -> Kyverno).
  5. Evaluates Kubernetes and Flux engine compatibility matrix constraints.
  6. Emits structured JSON validation reports and exit codes for CI/CD gating.
  7. Pure Python standard library implementation (Zero external pip dependencies).
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

# ANSI Styling
CYAN = "\033[0;36m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
RED = "\033[0;31m"
MAGENTA = "\033[0;35m"
BOLD = "\033[1m"
NC = "\033[0m"


def log_banner(title: str):
    print(f"\n{CYAN}{BOLD}{'=' * 78}{NC}")
    print(f"{CYAN}{BOLD} MeshDefense: {title}{NC}")
    print(f"{CYAN}{BOLD}{'=' * 78}{NC}")


def parse_yaml_matrix(yaml_path: Path) -> List[Dict[str, Any]]:
    """Zero-dependency parser tailored for the Big Bang release matrix structure."""
    if not yaml_path.exists():
        raise FileNotFoundError(f"Matrix file not found: {yaml_path}")

    content = yaml_path.read_text(encoding="utf-8")
    versions: List[Dict[str, Any]] = []
    current_entry: Dict[str, Any] = {}
    current_section: Optional[str] = None
    current_list_item: Optional[Dict[str, Any]] = None

    for line in content.splitlines():
        clean = line.split("#")[0].rstrip()
        if not clean.strip():
            continue

        indent = len(clean) - len(clean.lstrip())

        # Top-level version item: - bigbang_version: "..."
        if clean.strip().startswith("- bigbang_version:"):
            if current_entry:
                if current_list_item and current_section:
                    current_entry[current_section].append(current_list_item)
                    current_list_item = None
                versions.append(current_entry)
            current_entry = {}
            val = clean.split(":", 1)[1].strip().strip('"\'')
            current_entry["bigbang_version"] = val
            current_entry["core_packages"] = {}
            current_entry["breaking_changes"] = []
            current_entry["deprecations"] = []
            current_entry["kubernetes_versions"] = []
            current_section = None
            current_list_item = None
            continue

        # Major sections (e.g. core_packages:, breaking_changes:, deprecations:, kubernetes_versions:)
        sec_match = re.match(r"^\s{4}([a-zA-Z0-9_-]+):\s*(.*)$", clean)
        if sec_match:
            sec_name = sec_match.group(1)
            val = sec_match.group(2).strip().strip('"\'')
            if current_list_item and current_section:
                current_entry[current_section].append(current_list_item)
                current_list_item = None

            if not val:
                current_section = sec_name
                if sec_name not in current_entry:
                    if sec_name in ["breaking_changes", "deprecations", "kubernetes_versions"]:
                        current_entry[sec_name] = []
                    else:
                        current_entry[sec_name] = {}
            else:
                current_entry[sec_name] = val
                current_section = None
            continue

        # Section content with indentation 6+
        if current_section == "core_packages":
            pkg_match = re.match(r"^\s{6}([a-zA-Z0-9_-]+):\s*(.*)$", clean)
            if pkg_match:
                pkg_k = pkg_match.group(1)
                pkg_v = pkg_match.group(2).strip().strip('"\'')
                current_entry["core_packages"][pkg_k] = pkg_v
            continue

        if current_section == "kubernetes_versions":
            k8s_match = re.match(r"^\s{6}-\s*\"?([0-9.]+)\"?$", clean)
            if k8s_match:
                current_entry["kubernetes_versions"].append(k8s_match.group(1))
            continue

        if current_section == "breaking_changes":
            if clean.strip().startswith("- "):
                if current_list_item:
                    current_entry["breaking_changes"].append(current_list_item)
                current_list_item = {}
                clean_item = clean.strip()[2:]
                item_match = re.match(r"^([a-zA-Z0-9_-]+):\s*(.*)$", clean_item)
                if item_match:
                    current_list_item[item_match.group(1)] = item_match.group(2).strip().strip('"\'')
            else:
                item_match = re.match(r"^\s{8}([a-zA-Z0-9_-]+):\s*(.*)$", clean)
                if item_match and current_list_item is not None:
                    current_list_item[item_match.group(1)] = item_match.group(2).strip().strip('"\'')
            continue

        if current_section == "deprecations":
            if clean.strip().startswith("- "):
                if current_list_item:
                    current_entry["deprecations"].append(current_list_item)
                current_list_item = {}
                clean_item = clean.strip()[2:]
                item_match = re.match(r"^([a-zA-Z0-9_-]+):\s*(.*)$", clean_item)
                if item_match:
                    current_list_item[item_match.group(1)] = item_match.group(2).strip().strip('"\'')
            else:
                item_match = re.match(r"^\s{8}([a-zA-Z0-9_-]+):\s*(.*)$", clean)
                if item_match and current_list_item is not None:
                    current_list_item[item_match.group(1)] = item_match.group(2).strip().strip('"\'')
            continue

    if current_list_item and current_section in ["breaking_changes", "deprecations"]:
        current_entry[current_section].append(current_list_item)
    if current_entry:
        versions.append(current_entry)

    return versions


def get_current_release_from_chart(chart_yaml_path: Path) -> str:
    if not chart_yaml_path.exists():
        return "3.30.0"
    content = chart_yaml_path.read_text(encoding="utf-8")
    for line in content.splitlines():
        if line.startswith("version:"):
            return line.split(":", 1)[1].strip().strip('"\'')
    return "3.30.0"


def find_release_entry(matrix: List[Dict[str, Any]], version: str) -> Optional[Dict[str, Any]]:
    for entry in matrix:
        if str(entry.get("bigbang_version")) == str(version):
            return entry
    return None


def compare_versions(current_entry: Dict[str, Any], target_entry: Dict[str, Any]) -> Dict[str, Any]:
    current_pkgs = current_entry.get("core_packages", {})
    target_pkgs = target_entry.get("core_packages", {})

    all_pkgs = sorted(list(set(list(current_pkgs.keys()) + list(target_pkgs.keys()))))
    package_diffs = []

    for pkg in all_pkgs:
        cur_v = current_pkgs.get(pkg, "N/A")
        tgt_v = target_pkgs.get(pkg, "N/A")
        changed = cur_v != tgt_v
        package_diffs.append({
            "package": pkg,
            "current_version": cur_v,
            "target_version": tgt_v,
            "changed": changed
        })

    breaking = target_entry.get("breaking_changes", [])
    deprecations = target_entry.get("deprecations", [])

    cur_k8s = current_entry.get("kubernetes_versions", [])
    tgt_k8s = target_entry.get("kubernetes_versions", [])
    k8s_overlap = list(set(cur_k8s).intersection(set(tgt_k8s)))

    return {
        "current_release": current_entry.get("bigbang_version"),
        "target_release": target_entry.get("bigbang_version"),
        "package_diffs": package_diffs,
        "breaking_changes": breaking,
        "deprecations": deprecations,
        "kubernetes_compatibility": {
            "current_supported": cur_k8s,
            "target_supported": tgt_k8s,
            "common_supported": sorted(k8s_overlap)
        },
        "flux_requirement": {
            "current": current_entry.get("flux_version", ">= 2.3.0"),
            "target": target_entry.get("flux_version", ">= 2.3.0")
        }
    }


def print_diff_report(diff: Dict[str, Any]):
    log_banner(f"Big Bang Upstream Diff: {diff['current_release']} -> {diff['target_release']}")

    print(f"\n{BOLD}1. Component Chart Version Bumps:{NC}")
    print(f"{'-' * 78}")
    print(f"{'Package':<24} | {'Current Version':<22} | {'Target Version':<22}")
    print(f"{'-' * 78}")
    for item in diff["package_diffs"]:
        pkg = item["package"]
        cur = item["current_version"]
        tgt = item["target_version"]
        if item["changed"]:
            print(f"{CYAN}{pkg:<24}{NC} | {YELLOW}{cur:<22}{NC} | {GREEN}{BOLD}{tgt:<22}{NC}")
        else:
            print(f"{pkg:<24} | {cur:<22} | {tgt:<22}")
    print(f"{'-' * 78}")

    print(f"\n{BOLD}2. Breaking Structural & Schema Changes ({len(diff['breaking_changes'])} detected):{NC}")
    if diff["breaking_changes"]:
        for i, b in enumerate(diff["breaking_changes"], 1):
            sev = b.get("severity", "MEDIUM")
            sev_color = RED if sev in ["CRITICAL", "HIGH"] else YELLOW
            print(f"  [{i}] {sev_color}{BOLD}[{sev}]{NC} {BOLD}{b.get('package')}{NC} ({b.get('component')}):")
            print(f"      {b.get('description')}")
    else:
        print(f"  {GREEN}[OK] No breaking structural changes identified for this upgrade path.{NC}")

    print(f"\n{BOLD}3. Component Deprecations & Retirements ({len(diff['deprecations'])} detected):{NC}")
    if diff["deprecations"]:
        for i, d in enumerate(diff["deprecations"], 1):
            print(f"  [{i}] {MAGENTA}{BOLD}[DEPRECATED]{NC} {BOLD}{d.get('target')}{NC}: {d.get('timeline')}")
    else:
        print(f"  {GREEN}[OK] No component deprecations reported.{NC}")

    print(f"\n{BOLD}4. Platform Engine Compatibility:{NC}")
    k8s = diff["kubernetes_compatibility"]
    print(f"  - Common Supported K8s Versions: {GREEN}{', '.join(k8s['common_supported'])}{NC}")
    print(f"  - Target Flux Engine Requirement: {CYAN}{diff['flux_requirement']['target']}{NC}")

    critical_count = sum(1 for b in diff["breaking_changes"] if b.get("severity") in ["CRITICAL", "HIGH"])
    print(f"\n{BOLD}5. Upgrade Risk & Action Summary:{NC}")
    if critical_count > 0:
        print(f"  {RED}{BOLD}[WARNING] High-risk upgrade detected! {critical_count} critical/high breaking change(s) require operator remediation before initiating Flux upgrade.{NC}")
    else:
        print(f"  {GREEN}{BOLD}[PASS] Upgrade validation passed with minimal structural risk.{NC}")


def main():
    parser = argparse.ArgumentParser(
        description="MeshDefense Big Bang Upstream Release Diff & Breaking Change Validation Utility (Story 6.1)"
    )
    parser.add_argument(
        "--current",
        type=str,
        default=None,
        help="Currently running Big Bang version (defaults to chart/Chart.yaml version, e.g., 3.30.0)"
    )
    parser.add_argument(
        "--target",
        type=str,
        default="3.31.0",
        help="Target upstream Big Bang version to validate (default: 3.31.0)"
    )
    parser.add_argument(
        "--matrix",
        type=str,
        default="meshdefense-bigbang/versions/release-matrix.yaml",
        help="Path to Big Bang release matrix YAML file"
    )
    parser.add_argument(
        "--chart",
        type=str,
        default="meshdefense-bigbang/chart/Chart.yaml",
        help="Path to current Big Bang umbrella Chart.yaml"
    )
    parser.add_argument(
        "--output",
        type=str,
        choices=["terminal", "json"],
        default="terminal",
        help="Output format (terminal, json)"
    )
    parser.add_argument(
        "--fail-on-critical",
        action="store_true",
        help="Exit with non-zero status code if critical/high breaking changes are detected (useful for CI/CD gates)"
    )

    args = parser.parse_args()

    project_root = Path(__file__).resolve().parent.parent.parent
    matrix_path = project_root / args.matrix if not Path(args.matrix).is_absolute() else Path(args.matrix)
    chart_path = project_root / args.chart if not Path(args.chart).is_absolute() else Path(args.chart)

    try:
        version_matrix = parse_yaml_matrix(matrix_path)
    except Exception as e:
        print(f"{RED}Error loading release matrix: {e}{NC}", file=sys.stderr)
        sys.exit(1)

    current_ver = args.current
    if not current_ver:
        try:
            current_ver = get_current_release_from_chart(chart_path)
        except Exception:
            current_ver = "3.30.0"

    target_ver = args.target

    current_entry = find_release_entry(version_matrix, current_ver)
    target_entry = find_release_entry(version_matrix, target_ver)

    if not current_entry:
        print(f"{RED}Error: Current release '{current_ver}' not found in release matrix {matrix_path}{NC}", file=sys.stderr)
        sys.exit(1)

    if not target_entry:
        print(f"{RED}Error: Target release '{target_ver}' not found in release matrix {matrix_path}{NC}", file=sys.stderr)
        sys.exit(1)

    diff = compare_versions(current_entry, target_entry)

    if args.output == "json":
        print(json.dumps(diff, indent=2))
    else:
        print_diff_report(diff)

    if args.fail_on_critical:
        critical_count = sum(1 for b in diff["breaking_changes"] if b.get("severity") in ["CRITICAL", "HIGH"])
        if critical_count > 0:
            print(f"\n{RED}[CI-GATE] Failing pipeline execution due to {critical_count} critical/high breaking changes.{NC}", file=sys.stderr)
            sys.exit(2)


if __name__ == "__main__":
    main()

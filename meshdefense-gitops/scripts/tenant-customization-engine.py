#!/usr/bin/env python3
"""
MeshDefense Tenant Customization Engine (Story 4.2)
===================================================
Generates hierarchical Kustomize overlays (Base -> Environment -> Tenant)
from a single tenant-values.yaml specification.

Ensures:
  - Immutable Security Baseline (STRICT mTLS, Restricted PSS, NetworkPolicy isolation).
  - Parameterized Tenant Ingress (DNS, Cert-Manager TLS Certificate, Istio Gateway).
  - Parameterized Resource Governance (CPU/Memory ResourceQuota and LimitRange).
"""

import argparse
import os
import re
import sys
from pathlib import Path

# Template Kustomization YAML for generated tenant overlay
KUSTOMIZATION_TEMPLATE = """apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../base

namespace: {tenant_name}

patches:
  - target:
      kind: Namespace
      name: tenant-template
    patch: |-
      - op: replace
        path: /metadata/name
        value: {tenant_name}
  - target:
      kind: ResourceQuota
      name: tenant-compute-quota
    patch: |-
      - op: replace
        path: /metadata/namespace
        value: {tenant_name}
      - op: replace
        path: /spec/hard/requests.cpu
        value: "{req_cpu}"
      - op: replace
        path: /spec/hard/requests.memory
        value: "{req_mem}"
      - op: replace
        path: /spec/hard/limits.cpu
        value: "{lim_cpu}"
      - op: replace
        path: /spec/hard/limits.memory
        value: "{lim_mem}"
      - op: replace
        path: /spec/hard/pods
        value: "{max_pods}"
  - target:
      kind: LimitRange
      name: tenant-limits
    patch: |-
      - op: replace
        path: /metadata/namespace
        value: {tenant_name}
  - target:
      kind: NetworkPolicy
      name: tenant-isolation-policy
    patch: |-
      - op: replace
        path: /metadata/namespace
        value: {tenant_name}
  - target:
      kind: PeerAuthentication
      name: default
    patch: |-
      - op: replace
        path: /metadata/namespace
        value: {tenant_name}
  - target:
      kind: Certificate
      name: tenant-ingress-cert
    patch: |-
      - op: replace
        path: /metadata/name
        value: {tls_secret_name}
      - op: replace
        path: /spec/secretName
        value: {tls_secret_name}
      - op: replace
        path: /spec/dnsNames
        value:
{dns_names_yaml}
  - target:
      kind: Gateway
      name: tenant-gateway
    patch: |-
      - op: replace
        path: /metadata/name
        value: {tenant_name}-gateway
      - op: replace
        path: /spec/servers/0/tls/credentialName
        value: {tls_secret_name}
      - op: replace
        path: /spec/servers/0/hosts
        value:
{dns_names_yaml}
"""


def parse_simple_yaml(file_path: Path) -> dict:
    """Parses hierarchical YAML dictionary without requiring external packages."""
    lines = file_path.read_text().splitlines()
    root = {}
    stack = [(-1, root)]  # (indent_level, dict_or_list)

    for line in lines:
        raw = line.split("#")[0].rstrip()
        if not raw.strip():
            continue

        indent = len(raw) - len(raw.lstrip())
        content = raw.strip()

        # Pop stack until top is parent
        while len(stack) > 1 and stack[-1][0] >= indent:
            stack.pop()

        parent = stack[-1][1]

        if content.startswith("- "):
            item = content[2:].strip().strip('"\'')
            if isinstance(parent, list):
                parent.append(item)
            elif isinstance(parent, dict):
                # Look for 'hosts' list or default list
                if "hosts" not in parent or not isinstance(parent["hosts"], list):
                    parent["hosts"] = []
                parent["hosts"].append(item)
        elif ":" in content:
            k, v = content.split(":", 1)
            k = k.strip()
            v = v.strip().strip('"\'')
            if v == "":
                new_dict = {}
                if isinstance(parent, dict):
                    parent[k] = new_dict
                stack.append((indent, new_dict))
            else:
                if isinstance(parent, dict):
                    parent[k] = v

    return root


def generate_tenant_overlay(values_file: Path, output_dir: Path):
    """Generates kustomization.yaml from tenant-values.yaml."""
    spec = parse_simple_yaml(values_file)
    t = spec.get("tenant", {})
    name = t.get("name", "tenant-custom")
    domain = t.get("domain", f"{name}.apps.internal")
    
    res = t.get("resources", {})
    reqs = res.get("requests", {})
    lims = res.get("limits", {})
    
    req_cpu = reqs.get("cpu", "4")
    req_mem = reqs.get("memory", "8Gi")
    lim_cpu = lims.get("cpu", "8")
    lim_mem = lims.get("memory", "16Gi")
    max_pods = res.get("pods", "50")
    
    ing = t.get("ingress", {})
    hosts = ing.get("hosts", [domain, f"*.{domain}"])
    tls_secret_name = ing.get("tls_secret_name", f"{name}-ingress-cert")
    
    dns_yaml_lines = "\n".join([f"          - \"{h}\"" for h in hosts])
    
    rendered_kustomize = KUSTOMIZATION_TEMPLATE.format(
        tenant_name=name,
        req_cpu=req_cpu,
        req_mem=req_mem,
        lim_cpu=lim_cpu,
        lim_mem=lim_mem,
        max_pods=max_pods,
        tls_secret_name=tls_secret_name,
        dns_names_yaml=dns_yaml_lines
    )
    
    output_dir.mkdir(parents=True, exist_ok=True)
    out_file = output_dir / "kustomization.yaml"
    out_file.write_text(rendered_kustomize)
    print(f"[+] Successfully generated tenant Kustomize overlay: {out_file}")


def main():
    parser = argparse.ArgumentParser(description="MeshDefense Big Bang Tenant Customization Engine")
    parser.add_argument("--values", required=True, help="Path to tenant-values.yaml")
    parser.add_argument("--output-dir", required=True, help="Output directory for generated tenant overlay")
    args = parser.parse_args()

    v_path = Path(args.values).resolve()
    out_dir = Path(args.output_dir).resolve()
    
    if not v_path.exists():
        print(f"[-] Values file not found: {v_path}", file=sys.stderr)
        sys.exit(1)
        
    generate_tenant_overlay(v_path, out_dir)


if __name__ == "__main__":
    main()

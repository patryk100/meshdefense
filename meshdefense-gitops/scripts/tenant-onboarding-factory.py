#!/usr/bin/env python3
"""
MeshDefense Automated Tenant Onboarding GitOps Factory (Story 4.8)
==================================================================
Reads a single declarative developer custom YAML specification (defining app name,
service account, namespace, resource quotas, and egress rules) and automatically generates:
  1. Hardened Tenant Namespace (with Restricted Pod Security Standard & Istio injection labels)
  2. STRICT mTLS Istio PeerAuthentication (NIST 800-53 SC-8)
  3. Istio Egress ServiceEntry manifests for authorized egress destinations
  4. Kyverno Policy Exceptions (PolicyException CRD v2beta1)
  5. Scoped AWS IRSA IAM Role Terraform configuration for AWS STS WebIdentity authentication
  6. Ingress Certificate & Gateway configuration (Cert-Manager ECDSA-256)
  7. Compute ResourceQuota & LimitRange governance policies
  8. Default Deny-All NetworkPolicy with least-privilege egress whitelisting

Enables application developer self-service deployment onto the hardened platform
without breaking DoD IL6 zero-trust guardrails.
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path


def parse_yaml_text(text: str):
    """
    Indentation-based recursive parser for YAML subset:
    Supports: dictionaries, nested dicts, lists of scalars, lists of dicts.
    Zero external dependencies required.
    """
    raw_lines = text.splitlines()
    cleaned = []
    for line in raw_lines:
        no_comment = line.split("#")[0].rstrip()
        if no_comment.strip():
            cleaned.append(no_comment)

    def parse_block(idx, current_indent):
        res = None
        while idx < len(cleaned):
            line = cleaned[idx]
            indent = len(line) - len(line.lstrip())
            if indent < current_indent:
                break

            stripped = line.strip()

            if stripped.startswith("- "):
                if res is None:
                    res = []
                elif not isinstance(res, list):
                    break

                content = stripped[2:].strip()
                if not content:
                    val, next_idx = parse_block(idx + 1, indent + 2)
                    res.append(val)
                    idx = next_idx
                    continue
                elif ":" in content and not (content.startswith('"') or content.startswith("'")):
                    k, v = content.split(":", 1)
                    k = k.strip()
                    v = v.strip().strip('"\'')
                    sub_dict = {}
                    if v:
                        sub_dict[k] = v
                        next_idx = idx + 1
                        sub_dict_more, final_idx = parse_dict_entries(next_idx, indent + 2)
                        sub_dict.update(sub_dict_more)
                        res.append(sub_dict)
                        idx = final_idx
                        continue
                    else:
                        sub_val, next_idx = parse_block(idx + 1, indent + 4)
                        sub_dict[k] = sub_val
                        next_idx2 = next_idx
                        sub_dict_more, final_idx = parse_dict_entries(next_idx2, indent + 2)
                        sub_dict.update(sub_dict_more)
                        res.append(sub_dict)
                        idx = final_idx
                        continue
                else:
                    res.append(content.strip('"\''))
                    idx += 1
                    continue
            elif ":" in stripped:
                if res is None:
                    res = {}
                elif not isinstance(res, dict):
                    break
                k, v = stripped.split(":", 1)
                k = k.strip()
                v = v.strip().strip('"\'')
                if not v:
                    val, next_idx = parse_block(idx + 1, indent + 2)
                    res[k] = val
                    idx = next_idx
                    continue
                else:
                    res[k] = v
                    idx += 1
                    continue
            else:
                idx += 1
        return res, idx

    def parse_dict_entries(idx, dict_indent):
        d = {}
        while idx < len(cleaned):
            line = cleaned[idx]
            indent = len(line) - len(line.lstrip())
            if indent < dict_indent:
                break
            if indent > dict_indent:
                break
            stripped = line.strip()
            if stripped.startswith("- "):
                break
            if ":" in stripped:
                k, v = stripped.split(":", 1)
                k = k.strip()
                v = v.strip().strip('"\'')
                if not v:
                    val, next_idx = parse_block(idx + 1, indent + 2)
                    d[k] = val
                    idx = next_idx
                else:
                    d[k] = v
                    idx += 1
            else:
                idx += 1
        return d, idx

    parsed, _ = parse_block(0, 0)
    return parsed or {}


def generate_namespace_manifest(tenant_meta: dict, resources_meta: dict) -> str:
    name = tenant_meta.get("name")
    ns = tenant_meta.get("namespace", name)
    sa = tenant_meta.get("serviceAccount", f"{name}-sa")
    
    req_cpu = resources_meta.get("requests", {}).get("cpu", "4")
    req_mem = resources_meta.get("requests", {}).get("memory", "8Gi")
    lim_cpu = resources_meta.get("limits", {}).get("cpu", "8")
    lim_mem = resources_meta.get("limits", {}).get("memory", "16Gi")
    max_pods = resources_meta.get("pods", "50")
    max_services = resources_meta.get("services", "20")

    return f"""# --------------------------------------------------------------------------------------------------
# MeshDefense Tenant Namespace & Governance: {ns}
# Enforces NIST SP 800-53 AC-3, SC-7 and DoD Enterprise DevSecOps Reference Design
# --------------------------------------------------------------------------------------------------
apiVersion: v1
kind: Namespace
metadata:
  name: {ns}
  labels:
    istio-injection: enabled
    meshdefense.io/tenant: "{name}"
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {sa}
  namespace: {ns}
  labels:
    app.kubernetes.io/name: {name}
    meshdefense.io/tenant: "{name}"
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/meshdefense-{tenant_meta.get('environment', 'poc-minimal')}-irsa-{name}"
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: {name}-compute-quota
  namespace: {ns}
spec:
  hard:
    requests.cpu: "{req_cpu}"
    requests.memory: "{req_mem}"
    limits.cpu: "{lim_cpu}"
    limits.memory: "{lim_mem}"
    pods: "{max_pods}"
    services: "{max_services}"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: {name}-limits
  namespace: {ns}
spec:
  limits:
    - default:
        cpu: 500m
        memory: 512Mi
      defaultRequest:
        cpu: 100m
        memory: 128Mi
      type: Container
"""


def generate_peer_authentication_manifest(tenant_meta: dict) -> str:
    name = tenant_meta.get("name")
    ns = tenant_meta.get("namespace", name)

    return f"""# --------------------------------------------------------------------------------------------------
# MeshDefense Zero-Trust Mutual TLS PeerAuthentication: {ns}
# Enforces STRICT mTLS pod-to-pod encryption rejecting plaintext (NIST 800-53 SC-8)
# --------------------------------------------------------------------------------------------------
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: {ns}
  labels:
    meshdefense.io/tenant: "{name}"
spec:
  mtls:
    mode: STRICT
"""


def generate_egress_service_entries(tenant_meta: dict, egress_rules: list) -> str:
    name = tenant_meta.get("name")
    ns = tenant_meta.get("namespace", name)

    if not egress_rules:
        return f"""# No external egress rules specified for tenant {name}
# Outbound traffic remains restricted to cluster mesh boundaries
"""

    manifests = [
        f"# --------------------------------------------------------------------------------------------------\n"
        f"# MeshDefense Egress ServiceEntries: {ns}\n"
        f"# Declarative external service registration enforcing zero-trust boundaries (NIST 800-53 SC-7)\n"
        f"# --------------------------------------------------------------------------------------------------"
    ]

    for rule in egress_rules:
        rule_name = rule.get("name", f"{name}-egress")
        hosts = rule.get("hosts", [])
        if isinstance(hosts, str):
            hosts = [hosts]
        
        resolution = rule.get("resolution", "DNS")
        location = rule.get("location", "MESH_EXTERNAL")
        export_to = rule.get("exportTo", ["."])
        if isinstance(export_to, str):
            export_to = [export_to]

        ports = rule.get("ports", [])
        ports_yaml = []
        for p in ports:
            p_num = p.get("number", 443)
            p_proto = p.get("protocol", "HTTPS")
            p_name = p.get("name", f"{p_proto.lower()}-{p_num}")
            ports_yaml.append(f"""    - number: {p_num}
      name: {p_name}
      protocol: {p_proto}""")

        hosts_yaml = "\n".join([f"    - \"{h}\"" for h in hosts])
        ports_block = "\n".join(ports_yaml)
        export_yaml = "\n".join([f"    - \"{e}\"" for e in export_to])

        entry = f"""apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: {rule_name}
  namespace: {ns}
  labels:
    app.kubernetes.io/name: {name}
    meshdefense.io/tenant: "{name}"
spec:
  hosts:
{hosts_yaml}
  location: {location}
  resolution: {resolution}
  exportTo:
{export_yaml}
  ports:
{ports_block}"""
        manifests.append(entry)

    return "\n---\n".join(manifests) + "\n"


def generate_network_policy_manifest(tenant_meta: dict, egress_rules: list) -> str:
    name = tenant_meta.get("name")
    ns = tenant_meta.get("namespace", name)

    egress_ports = [
        """    # DNS resolution
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53""",
        """    # Intra-namespace pod-to-pod
    - to:
        - podSelector: {}""",
        """    # Internal VPC endpoints and platform services
    - to:
        - ipBlock:
            cidr: 10.104.0.0/16"""
    ]

    for rule in egress_rules:
        ports = rule.get("ports", [])
        for p in ports:
            p_num = p.get("number", 443)
            p_proto = p.get("protocol", "TCP")
            egress_ports.append(f"""    # Egress: {rule.get('name', 'custom-service')}
    - ports:
        - protocol: {p_proto}
          port: {p_num}""")

    egress_block = "\n".join(egress_ports)

    return f"""# --------------------------------------------------------------------------------------------------
# MeshDefense Tenant Microsegmentation NetworkPolicy: {ns}
# Default-Deny-All with explicit least privilege Ingress and Egress (NIST 800-53 SC-7)
# --------------------------------------------------------------------------------------------------
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {name}-isolation-policy
  namespace: {ns}
  labels:
    meshdefense.io/tenant: "{name}"
spec:
  podSelector: {{}}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Intra-namespace ingress
    - from:
        - podSelector: {{}}
    # Ingress from Istio Ingress Gateway
    - from:
        - namespaceSelector:
            matchLabels:
              istio.io/deploystatus: "gateway"
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: istio-system
    # Ingress from Monitoring / Prometheus scraper
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: monitoring
      ports:
        - protocol: TCP
          port: 8080
        - protocol: TCP
          port: 9090
  egress:
{egress_block}
"""


def generate_kyverno_exceptions_manifest(tenant_meta: dict, exceptions: list) -> str:
    name = tenant_meta.get("name")
    ns = tenant_meta.get("namespace", name)

    if not exceptions:
        return f"""# No Kyverno policy exceptions requested for tenant {name}
# Strict admission enforcement active across all pods
"""

    manifests = [
        f"# --------------------------------------------------------------------------------------------------\n"
        f"# MeshDefense Scoped Kyverno PolicyExceptions (v2beta1): {ns}\n"
        f"# Authorized granular exemptions for specialized workloads (NIST 800-53 CM-7)\n"
        f"# --------------------------------------------------------------------------------------------------"
    ]

    for idx, exc in enumerate(exceptions):
        pol_name = exc.get("policyName", "enforce-harbor-cosign-verification")
        rule_names = exc.get("ruleNames", ["verify-ironbank-and-harbor-signatures"])
        if isinstance(rule_names, str):
            rule_names = [rule_names]
        reason = exc.get("reason", "Authorized tenant workload exception")
        sa = tenant_meta.get("serviceAccount", f"{name}-sa")

        rules_yaml = "\n".join([f"          - \"{r}\"" for r in rule_names])

        doc = f"""apiVersion: kyverno.io/v2beta1
kind: PolicyException
metadata:
  name: {name}-exception-{idx + 1}
  namespace: {ns}
  labels:
    app.kubernetes.io/name: {name}
    meshdefense.io/tenant: "{name}"
spec:
  exceptions:
    - policyName: {pol_name}
      ruleNames:
{rules_yaml}
  match:
    any:
      - resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
          namespaces:
            - {ns}
          selector:
            matchLabels:
              app.kubernetes.io/name: {name}
  conditions:
    all:
      - key: "{{{{ request.operation }}}}"
        operator: In
        values:
          - CREATE
          - UPDATE
"""
        manifests.append(doc)

    return "\n---\n".join(manifests) + "\n"


def generate_ingress_manifest(tenant_meta: dict, ingress_meta: dict) -> str:
    name = tenant_meta.get("name")
    enabled = str(ingress_meta.get("enabled", "true")).lower() == "true"
    if not enabled:
        return f"# Ingress disabled for tenant {name}\n"

    hosts = ingress_meta.get("hosts", [f"{name}.apps.meshdefense.internal"])
    if isinstance(hosts, str):
        hosts = [hosts]
    tls_secret = ingress_meta.get("tlsSecretName", f"{name}-ingress-cert")
    issuer = ingress_meta.get("issuer", "meshdefense-cluster-issuer")

    dns_yaml = "\n".join([f"    - \"{h}\"" for h in hosts])
    gw_hosts = "\n".join([f"        - \"{h}\"" for h in hosts])

    return f"""# --------------------------------------------------------------------------------------------------
# MeshDefense Tenant TLS Certificate & Istio Gateway: {name}
# ECDSA-256 automated certificate with 90-day validity (NIST 800-53 SC-8, SC-13)
# --------------------------------------------------------------------------------------------------
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: {name}-ingress-cert
  namespace: istio-system
  labels:
    meshdefense.io/tenant: "{name}"
spec:
  secretName: {tls_secret}
  duration: 2160h # 90 days
  renewBefore: 720h # 30 days
  isCA: false
  privateKey:
    algorithm: ECDSA
    size: 256
  issuerRef:
    name: {issuer}
    kind: ClusterIssuer
    group: cert-manager.io
  dnsNames:
{dns_yaml}
---
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: {name}-gateway
  namespace: istio-system
  labels:
    meshdefense.io/tenant: "{name}"
spec:
  selector:
    app: istio-ingressgateway
  servers:
    - port:
        number: 443
        name: https-{name}
        protocol: HTTPS
      tls:
        mode: SIMPLE
        credentialName: {tls_secret}
      hosts:
{gw_hosts}
"""


def generate_irsa_terraform_module(tenant_meta: dict, irsa_meta: dict) -> str:
    name = tenant_meta.get("name")
    ns = tenant_meta.get("namespace", name)
    sa = tenant_meta.get("serviceAccount", f"{name}-sa")
    env = tenant_meta.get("environment", "poc-minimal")
    
    enabled = str(irsa_meta.get("enabled", "true")).lower() == "true"
    if not enabled:
        return f"# IRSA disabled for tenant {name}\n"

    role_name = irsa_meta.get("roleName", f"meshdefense-{env}-irsa-{name}")
    desc = irsa_meta.get("description", f"Dedicated least-privilege IRSA role for tenant {name}")
    
    statements = irsa_meta.get("inlinePolicyStatements", [])
    stmt_json = json.dumps(statements, indent=4) if statements else "[]"
    managed_arns = irsa_meta.get("managedPolicyArns", [])
    managed_arns_str = json.dumps(managed_arns)

    return f"""# ==================================================================================================
# MeshDefense Tenant IRSA Terraform Configuration: {name}
# Generates scoped AWS IAM Role for Service Account (IRSA) via OIDC Trust (NIST 800-53 AC-3, AC-6)
# ==================================================================================================

locals {{
  tenant_{name.replace("-", "_")}_irsa_role = {{
    "{name}" = {{
      role_name                 = "{role_name}"
      role_description          = "{desc}"
      namespace                 = "{ns}"
      service_account           = "{sa}"
      managed_policy_arns       = {managed_arns_str}
      inline_policy_statements = {stmt_json}
      tags = {{
        Tenant     = "{name}"
        Namespace  = "{ns}"
        Component  = "tenant-application"
        Compliance = "NIST-800-53-AC-3_AC-6_SC-12_SC-13"
      }}
    }}
  }}
}}
"""


def generate_kustomization(output_dir: Path, manifest_files: list[str]):
    kust_lines = [
        "apiVersion: kustomize.config.k8s.io/v1beta1",
        "kind: Kustomization",
        "",
        "resources:"
    ]
    for mf in manifest_files:
        kust_lines.append(f"  - {mf}")
    
    out_file = output_dir / "kustomization.yaml"
    out_file.write_text("\n".join(kust_lines) + "\n")
    return out_file


def process_tenant_specification(spec_path: Path, output_dir: Path):
    content = spec_path.read_text()
    data = parse_yaml_text(content)

    spec = data.get("spec", data)
    tenant_meta = spec.get("tenant", {})
    if not tenant_meta:
        # Fallback to metadata
        meta = data.get("metadata", {})
        tenant_meta = {
            "name": meta.get("name", "custom-tenant"),
            "namespace": f"tenant-{meta.get('name', 'custom-tenant')}",
            "serviceAccount": f"{meta.get('name', 'custom-tenant')}-sa"
        }

    tenant_name = tenant_meta.get("name", "custom-tenant")
    tenant_ns = tenant_meta.get("namespace", f"tenant-{tenant_name}")
    tenant_sa = tenant_meta.get("serviceAccount", f"{tenant_name}-sa")
    tenant_meta["namespace"] = tenant_ns
    tenant_meta["serviceAccount"] = tenant_sa

    resources_meta = spec.get("resources", {})
    ingress_meta = spec.get("ingress", {})
    egress_rules = spec.get("egressRules", [])
    if isinstance(egress_rules, dict):
        egress_rules = [egress_rules]
    irsa_meta = spec.get("irsa", {})
    exceptions = spec.get("kyvernoExceptions", [])
    if isinstance(exceptions, dict):
        exceptions = [exceptions]

    output_dir.mkdir(parents=True, exist_ok=True)

    manifest_files = []

    # 1. Namespace & Compute Quota
    f_ns = output_dir / "01-tenant-namespace.yaml"
    f_ns.write_text(generate_namespace_manifest(tenant_meta, resources_meta))
    manifest_files.append("01-tenant-namespace.yaml")

    # 2. STRICT mTLS PeerAuthentication
    f_mtls = output_dir / "02-peer-authentication.yaml"
    f_mtls.write_text(generate_peer_authentication_manifest(tenant_meta))
    manifest_files.append("02-peer-authentication.yaml")

    # 3. Egress ServiceEntry
    f_egress = output_dir / "03-egress-serviceentry.yaml"
    f_egress.write_text(generate_egress_service_entries(tenant_meta, egress_rules))
    manifest_files.append("03-egress-serviceentry.yaml")

    # 4. NetworkPolicy isolation
    f_netpol = output_dir / "04-network-policy.yaml"
    f_netpol.write_text(generate_network_policy_manifest(tenant_meta, egress_rules))
    manifest_files.append("04-network-policy.yaml")

    # 5. Kyverno PolicyExceptions
    f_kyv = output_dir / "05-kyverno-exceptions.yaml"
    f_kyv.write_text(generate_kyverno_exceptions_manifest(tenant_meta, exceptions))
    manifest_files.append("05-kyverno-exceptions.yaml")

    # 6. Ingress Certificate & Gateway
    f_ing = output_dir / "06-tenant-ingress.yaml"
    f_ing.write_text(generate_ingress_manifest(tenant_meta, ingress_meta))
    manifest_files.append("06-tenant-ingress.yaml")

    # 7. Kustomization
    generate_kustomization(output_dir, manifest_files)

    # 8. IRSA Terraform Snippet
    f_tf = output_dir / f"irsa-{tenant_name}.tf"
    f_tf.write_text(generate_irsa_terraform_module(tenant_meta, irsa_meta))

    print(f"[+] Automated Tenant Onboarding complete for '{tenant_name}':")
    print(f"    - Namespace:           {tenant_ns}")
    print(f"    - ServiceAccount:      {tenant_sa}")
    print(f"    - Manifests Output:    {output_dir}")
    print(f"    - IRSA Terraform:      {f_tf}")
    print(f"    - Kustomize Manifests: {len(manifest_files)} generated")


def main():
    parser = argparse.ArgumentParser(description="MeshDefense Automated Tenant Onboarding GitOps Factory")
    parser.add_argument("--spec", required=True, help="Path to declarative tenant onboarding YAML specification")
    parser.add_argument("--output-dir", required=True, help="Target directory for generated Kubernetes manifests & IRSA Terraform")
    args = parser.parse_args()

    spec_path = Path(args.spec).resolve()
    out_dir = Path(args.output_dir).resolve()

    if not spec_path.exists():
        print(f"[-] Specification file not found: {spec_path}", file=sys.stderr)
        sys.exit(1)

    process_tenant_specification(spec_path, out_dir)


if __name__ == "__main__":
    main()

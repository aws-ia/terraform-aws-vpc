#!/usr/bin/env bash
set -euo pipefail

module_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
graph_file="$(mktemp)"
trap 'rm -f "$graph_file"' EXIT

# Plan-only mock tests cannot detect an apply-time race: a deferred precondition
# must be an ancestor of the route write in Terraform's actual dependency graph.
terraform -chdir="$module_root" graph -type=plan >"$graph_file"
python3 - "$graph_file" <<'PY'
import re
import sys
from collections import defaultdict
from pathlib import Path

graph = defaultdict(set)
for source, target in re.findall(r'"([^"\n]+)"\s*->\s*"([^"\n]+)"', Path(sys.argv[1]).read_text()):
    graph[source].add(target)

def ancestors(node):
    seen = set()
    pending = list(graph[node])
    while pending:
        target = pending.pop()
        if target not in seen:
            seen.add(target)
            pending.extend(graph[target])
    return seen

guards = [
    "injected_route_table_identity_validation",
    "isolated_injected_route_table_validation",
    "route_table_routing_compatibility_validation",
    "attachment_contract_validation",
    "core_network_readiness",
]
failures = []
for resource in ["cwan_attachment", "cwan_attachment_ipv6"]:
    route = f"[root] aws_route.{resource} (expand)"
    if route not in graph:
        failures.append(f"Missing Cloud WAN route node: {route}")
        continue
    dependencies = ancestors(route)
    for guard in guards:
        expected = f"[root] terraform_data.{guard} (expand)"
        if expected not in dependencies:
            failures.append(f"aws_route.{resource} can execute before terraform_data.{guard}")

if failures:
    raise SystemExit("\n".join(failures))
print("Cloud WAN IPv4/IPv6 routes wait for identity, isolation, routing and attachment guards")
PY

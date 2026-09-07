#!/usr/bin/env bash
set -euo pipefail

module_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log_file="$(mktemp)"
trap 'rm -f "$log_file"' EXIT

cd "$module_root"
terraform init -backend=false -input=false -test-directory=tests-negative >/dev/null

if terraform test -no-color -test-directory=tests-negative >"$log_file" 2>&1; then
  echo "Injected isolated route table unexpectedly planned without explicit opt-in" >&2
  exit 1
fi

grep -Fq 'resource "terraform_data" "isolated_injected_route_table_validation"' "$log_file"
grep -Fq "role='isolated' with manage_route_table=false requires" "$log_file"
grep -Fq 'isolated_accepts_uninspected_route_table=true' "$log_file"

echo "Injected isolated route tables fail closed without explicit caller responsibility"

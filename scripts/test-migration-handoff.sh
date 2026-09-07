#!/usr/bin/env bash
set -euo pipefail

fixture_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../tests/fixtures/migration-v5-production" && pwd)"

terraform -chdir="$fixture_dir" init -backend=false -input=false -lockfile=readonly >/dev/null
log_file="$(mktemp)"
trap 'rm -f "$log_file"' EXIT

terraform -chdir="$fixture_dir" test -no-color -verbose >"$log_file" 2>&1

association='module.vpc.aws_vpc_ipv6_cidr_block_association.secondary["v4-ipv6"]'
grep -Fq "# $association will be imported" "$log_file"
if grep -Fq "# $association will be created" "$log_file"; then
  echo "IPv6 association planned as create instead of import" >&2
  exit 1
fi
if grep -Eq 'must be replaced|will be destroyed' "$log_file"; then
  echo "Migration handoff planned a replacement or destroy" >&2
  exit 1
fi
grep -Eq 'Plan: 1 to import, [0-9]+ to add, [0-9]+ to change, 0 to destroy\.' "$log_file"
grep -Fq 'Success! 2 passed, 0 failed.' "$log_file"

echo "Production IPv6 handoff imports the standalone association with zero creates of that association, replacements, or destroys"

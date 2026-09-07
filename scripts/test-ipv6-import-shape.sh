#!/usr/bin/env bash
set -euo pipefail

fixture_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../tests/fixtures/ipv6-import-shape" && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

export AWS_EC2_METADATA_DISABLED=true
terraform -chdir="$fixture_dir" init -backend=false -input=false -lockfile=readonly >/dev/null

association_id="vpc-cidr-assoc-0123456789abcdef0"
import_ids=(
  "$association_id"
  "$association_id,ipam-pool-0123456789abcdef0"
  "$association_id,ipam-pool-0123456789abcdef0,56"
)

for index in "${!import_ids[@]}"; do
  import_id="${import_ids[$index]}"
  log_file="$tmp_dir/import-$index.log"
  state_file="$tmp_dir/import-$index.tfstate"

  if terraform -chdir="$fixture_dir" import -no-color -input=false -lock=false \
    -state="$state_file" \
    'aws_vpc_ipv6_cidr_block_association.secondary["v4-ipv6"]' \
    "$import_id" >"$log_file" 2>&1; then
    echo "Importer unexpectedly reached a successful AWS read for $import_id" >&2
    exit 1
  fi

  grep -Fq "Importing from ID \"$import_id\"" "$log_file"
  grep -Fq 'Import prepared!' "$log_file"
  grep -Fq "Refreshing state... [id=$association_id]" "$log_file"
  grep -Fq 'Post "http://127.0.0.1:1/"' "$log_file"
done

echo "AWS provider 6.59 accepted 3 IPv6 association import ID forms"

#!/usr/bin/env bash
set -euo pipefail

module_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readme="$module_dir/README.md"
smoke_dir="$(mktemp -d "${TMPDIR:-/tmp}/vpc-v5-readme-usage.XXXXXX")"
trap 'rm -rf "$smoke_dir"' EXIT

awk '
  $0 == "## Usage" { in_usage = 1; next }
  in_usage && $0 == "```hcl" { in_hcl = 1; next }
  in_hcl && $0 == "```" { exit }
  in_hcl { print }
' "$readme" > "$smoke_dir/main.tf"

if ! grep -q '^module "vpc" {' "$smoke_dir/main.tf"; then
  echo "README Usage extraction did not produce the vpc module block" >&2
  exit 1
fi

# The quick start shows the Terraform Registry source as published; rewrite it
# to the local module so the smoke init works before the release exists.
if ! grep -q 'source  = "aws-ia/vpc/aws"' "$smoke_dir/main.tf"; then
  echo "README quick start must use the Terraform Registry source aws-ia/vpc/aws" >&2
  exit 1
fi
perl -0pi -e 's/source\s+=\s+"aws-ia\/vpc\/aws"\n\s*version\s+=\s+"~> 5\.0"/source = "'"${module_dir//\//\\/}"'"/' "$smoke_dir/main.tf"

terraform -chdir="$smoke_dir" init -backend=false -no-color

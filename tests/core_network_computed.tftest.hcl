mock_provider "aws" {
  override_during = plan
  mock_data "aws_partition" { defaults = { partition = "aws" } }
  mock_data "aws_region" { defaults = { region = "us-east-1" } }
  mock_data "aws_caller_identity" { defaults = { account_id = "123456789012" } }
  mock_data "aws_vpc" { defaults = { cidr_block = "10.98.0.0/16" } }
}

run "computed_ids_and_arns_keep_keys_plan_known" {
  command = plan
  module {
    source = "./tests/fixtures/computed-core-network-attachments"
  }
  assert {
    condition = (
      toset(output.keys.attachments) == toset(["created", "injected"]) &&
      toset(output.keys.created) == toset(["created"]) &&
      toset(output.keys.accepters) == toset(["injected"]) &&
      toset(output.keys.readiness) == toset(["created", "injected"]) &&
      toset(output.keys.route_tables) == toset(["isolated", "workload"]) &&
      toset(output.keys.routes) == toset([
        "injected/workload/cwan/created/10.0.0.0-8",
        "injected/workload/cwan/injected/172.16.0.0-12",
      ])
    )
    error_message = "Unknown network IDs/ARNs and injected attachment/accepter IDs must remain values, never for_each identity."
  }
}

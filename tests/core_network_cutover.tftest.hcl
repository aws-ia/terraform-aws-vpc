# Seed mocked state with both attachments before shifting traffic. Do not use
# override_during=plan: replacement route IDs must remain unknown in the plan.
mock_provider "aws" {
  mock_data "aws_partition" { defaults = { partition = "aws" } }
  mock_data "aws_region" { defaults = { region = "us-east-1" } }
  mock_data "aws_caller_identity" { defaults = { account_id = "123456789012" } }
  mock_resource "aws_subnet" {
    defaults = { arn = "arn:aws:ec2:us-east-1:123456789012:subnet/subnet-mock" }
  }
  mock_resource "aws_vpc_ipv6_cidr_block_association" {
    defaults = { ipv6_cidr_block = "2001:db8::/56" }
  }
}

run "seed_routes_on_blue_with_green_already_attached" {
  command   = apply
  state_key = "cloudwan-cutover"
  module {
    source = "./tests/fixtures/cloudwan-cutover-blue"
  }
  assert {
    condition     = length(output.route_ids) == 4 && toset(keys(output.attachment_ids)) == toset(["blue", "green"])
    error_message = "The cutover starts with four routes and both attachments in state."
  }
}

run "cutover_to_green_preserves_physical_route_ids" {
  command   = plan
  state_key = "cloudwan-cutover"
  module {
    source = "./tests/fixtures/cloudwan-cutover-green"
  }
  assert {
    condition = (
      output.route_ids == run.seed_routes_on_blue_with_green_already_attached.route_ids &&
      output.attachment_ids == run.seed_routes_on_blue_with_green_already_attached.attachment_ids &&
      toset(output.route_targets) == toset(["arn:aws:networkmanager::123456789012:core-network/core-network-1123456789abcdef0"])
    )
    error_message = "Cutover must update the Core Network target in place, preserving all routes and both attachments."
  }
}

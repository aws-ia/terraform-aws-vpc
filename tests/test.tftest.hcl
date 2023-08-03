run "validate_public_private_example_root" {
  command = plan

  variables {
    subnets = null
    az_count = null
    name = null
  }

  module {
    source = "./examples/public_private_flow_logs"
  }

  assert {
    condition = local.myval == "drew"
    error_message = "its not drew"
  }
}

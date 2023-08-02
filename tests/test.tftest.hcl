run "validate_public_private_example_root" {
  command = plan

  module {
    source = "./examples/public_private_flow_logs"
  }

  assert {
    condition = local.myval == "drew"
    error_message = "its not drew"
  }
}

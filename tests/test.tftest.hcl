variables {
  subnets = null
  az_count = null
  name = null
}

run "plan_validate_public_private_example_root" {
  command = plan

  module {
    source = "./examples/public_private_flow_logs"
  }

  assert {
    condition = local.myval == "drew"
    error_message = "its not drew"
  }
}

run "apply_validate_public_private_example_root" {
  module {
    source = "./examples/public_private_flow_logs"
  }

  assert {
    condition = module.vpc.vpc_attributes.cidr_block == "10.0.0.0/20"
    error_message = "Cidr block should be \"10.0.0.0/20\""
  }
}

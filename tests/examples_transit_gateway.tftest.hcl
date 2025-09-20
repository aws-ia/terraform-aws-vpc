run "validate" {
  command = apply

  module {
    source = "./examples/transit_gateway"
  }

  assert {
    condition     = length(module.vpc.tgw_subnet_attributes_by_az[data.aws_availability_zones.current.names[0]].tags) == 2
    error_message = "tgw subnet should have 2 tags total."
  }
  assert {
    condition     = length(module.vpc.private_subnet_attributes_by_az["private_dualstack/${data.aws_availability_zones.current.names[0]}"].tags) == 1
    error_message = "tgw subnets should have 1 tags total."
  }
}

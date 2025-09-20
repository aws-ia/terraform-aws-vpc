run "validate" {
  command = apply
  module {
    source = "./examples/optimized_ipv4_subnets"
  }

  assert {
    condition     = length(module.vpc.private_subnet_attributes_by_az["private/${data.aws_availability_zones.current.names[0]}"].tags) == 1
    error_message = "private subnets should have 1 tags total."
  }
}
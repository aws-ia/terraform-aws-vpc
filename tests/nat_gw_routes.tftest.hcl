run "validate_no_routes" {
  command = apply
  module {
    source = "./tests/hcl_fixtures/nat_gw_routes"
  }
  variables {
    nat_gateway_configuration = "none"
    route_to_nw               = false
  }

}

run "validate_single_nat_gw" {
  command = apply
  module {
    source = "./tests/hcl_fixtures/nat_gw_routes"
  }
  variables {
    nat_gateway_configuration = "single_az"
    route_to_nw               = true
  }
}

run "validate_many_nat_gw" {
  command = apply
  module {
    source = "./tests/hcl_fixtures/nat_gw_routes"
  }
  variables {
    nat_gateway_configuration = "all_azs"
    route_to_nw               = true
  }
}

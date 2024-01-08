run "ipam_setup" {
  command = apply
  module {
    source = "./tests/hcl_fixtures/ipam_base"
  }
}

run "validate_ipam_vpc" {
  command = apply
  module {
    source = "./examples/ipam"
  }
}

run "setup" {
  command = apply
  variables {
    az_count = 1
  }
  module {
    source = "./tests/hcl_fixtures/secondary_cidr_base"
  }
}

run "validate" {
  command = apply
  variables {
    az_count = 1
  }
  module {
    source = "./examples/secondary_cidr"
  }
}

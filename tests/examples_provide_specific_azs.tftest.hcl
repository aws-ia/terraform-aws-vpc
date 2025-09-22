run "validate" {
  command = apply
  module {
    source = "./examples/provide_specific_azs"
  }
}
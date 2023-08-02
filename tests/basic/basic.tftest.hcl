run "validate_locals" {
  command = plan

  assert {
    condition = local.myval == "drew"
    error_message = "its not drew"
  }

#  assert {
#    condition = aws_vpc.cidr_block.value == "10.0.0.0/16"
#    error_message = "invalid value"
#  }
}

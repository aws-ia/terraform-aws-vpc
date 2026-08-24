# Regression test for `var.azs` ordering.
#
# Subnet CIDRs are assigned in the order of `local.azs`. Since v4.7.0 that list comes
# from the `zone-name`-filtered availability zones data source, which returns names
# sorted alphabetically, so a caller-supplied `var.azs` is silently reordered. Callers
# whose AZ list is not alphabetical - e.g. one built from zone-ids, whose zone-name
# mapping is account-specific - get a different AZ to CIDR mapping than they asked for.
#
# `preserve_azs_order = true` opts in to using the list as given. The default stays
# `false`, so existing configurations plan exactly as they do today.

mock_provider "aws" {}
mock_provider "awscc" {}

override_data {
  target = data.aws_availability_zones.current
  values = {
    names = ["us-east-1a", "us-east-1b"]
  }
}

run "azs_sorted_by_default" {
  command = plan

  variables {
    name               = "azs-order-test"
    cidr_block         = "10.0.0.0/16"
    azs                = ["us-east-1b", "us-east-1a"]
    preserve_azs_order = false

    subnets = {
      private = {
        netmask = 24
      }
    }
  }

  assert {
    condition     = tolist(output.azs) == tolist(["us-east-1a", "us-east-1b"])
    error_message = "Default behavior must keep using the sorted data source order."
  }

  assert {
    condition     = aws_subnet.private["private/us-east-1a"].cidr_block == "10.0.0.0/24"
    error_message = "Sorted order must assign the first CIDR to the alphabetically first AZ."
  }
}

run "azs_order_preserved_when_opted_in" {
  command = plan

  variables {
    name               = "azs-order-test"
    cidr_block         = "10.0.0.0/16"
    azs                = ["us-east-1b", "us-east-1a"]
    preserve_azs_order = true

    subnets = {
      private = {
        netmask = 24
      }
    }
  }

  assert {
    condition     = tolist(output.azs) == tolist(["us-east-1b", "us-east-1a"])
    error_message = "preserve_azs_order = true must return var.azs in the order it was given."
  }

  assert {
    condition     = aws_subnet.private["private/us-east-1b"].cidr_block == "10.0.0.0/24"
    error_message = "preserve_azs_order = true must assign the first CIDR to the first AZ in var.azs."
  }

  assert {
    condition     = aws_subnet.private["private/us-east-1a"].cidr_block == "10.0.1.0/24"
    error_message = "preserve_azs_order = true must assign the second CIDR to the second AZ in var.azs."
  }
}

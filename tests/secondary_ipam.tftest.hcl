mock_provider "aws" {
  override_during = plan
  mock_resource "aws_vpc" {
    defaults = {
      id         = "vpc-mock"
      arn        = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-mock"
      cidr_block = "10.0.0.0/16"
    }
  }

  mock_data "aws_vpc" {
    defaults = {
      id         = "vpc-mock"
      cidr_block = "10.0.0.0/16"
      cidr_block_associations = [{
        association_id = "vpc-cidr-assoc-0123456789abcdef0"
        cidr_block     = "100.64.0.0/16"
        state          = "associated"
      }]
    }
  }

  mock_resource "aws_vpc_ipv4_cidr_block_association" {
    defaults = { id = "vpc-cidr-assoc-mock" }
  }

  mock_resource "aws_subnet" {
    defaults = {
      id  = "subnet-mock"
      arn = "arn:aws:ec2:us-east-1:123456789012:subnet/subnet-mock"
    }
  }

  mock_resource "aws_route_table" {
    defaults = { id = "rtb-mock" }
  }
}

run "secondary_static_and_ipam_are_stable" {
  command = plan

  variables {
    vpc = { name = "secondary-test" }
    addressing = {
      primary = { cidr_block = "10.0.0.0/16" }
      secondary = {
        analytics = {
          ipv4 = {
            ipam_pool_id   = "ipam-pool-0123456789abcdef0"
            netmask_length = 20
          }
        }
        shared-services = {
          ipv4 = { cidr_block = "100.64.0.0/20" }
        }
      }
    }
    availability_zones = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      analytics = {
        role = "private"
        ipv4 = {
          ipam_pool_id       = "ipam-pool-0123456789abcdef0"
          netmask_length     = 24
          secondary_cidr_key = "analytics"
        }
      }
      shared = {
        role = "private"
        ipv4 = {
          cidrs_by_az        = { "us-east-1a" = "100.64.0.0/24", "us-east-1b" = "100.64.1.0/24" }
          secondary_cidr_key = "shared-services"
        }
      }
    }
  }

  assert {
    condition = (
      toset(keys(aws_vpc_ipv4_cidr_block_association.secondary)) == toset(["analytics", "shared-services"]) &&
      aws_vpc_ipv4_cidr_block_association.secondary["analytics"].ipv4_ipam_pool_id == "ipam-pool-0123456789abcdef0" &&
      aws_vpc_ipv4_cidr_block_association.secondary["analytics"].ipv4_netmask_length == 20 &&
      aws_vpc_ipv4_cidr_block_association.secondary["shared-services"].cidr_block == "100.64.0.0/20" &&
      toset(keys(output.secondary_cidr_association_ids)) == toset(["analytics", "shared-services"])
    )
    error_message = "Secondary CIDR state identities must come from caller-owned keys and preserve static/IPAM arguments."
  }

  assert {
    condition = (
      aws_subnet.main["analytics/us-east-1a"].ipv4_ipam_pool_id == "ipam-pool-0123456789abcdef0" &&
      aws_subnet.main["analytics/us-east-1a"].ipv4_netmask_length == 24 &&
      aws_subnet.main["shared/us-east-1a"].cidr_block == "100.64.0.0/24" &&
      aws_subnet.main["shared/us-east-1b"].cidr_block == "100.64.1.0/24"
    )
    error_message = "Subnets selecting secondary associations must retain their planned IPAM/static attributes."
  }
}

run "inject_secondary_association" {
  command = plan

  variables {
    vpc = { name = "secondary-inject-test" }
    addressing = {
      primary = { cidr_block = "10.0.0.0/16" }
      secondary = {
        adopted = {
          ipv4 = {
            create         = false
            association_id = "vpc-cidr-assoc-0123456789abcdef0"
          }
        }
      }
    }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      adopted = {
        role = "private"
        ipv4 = {
          cidrs_by_az        = { "us-east-1a" = "100.64.10.0/24" }
          secondary_cidr_key = "adopted"
        }
      }
    }
  }

  assert {
    condition = (
      length(aws_vpc_ipv4_cidr_block_association.secondary) == 0 &&
      output.secondary_cidr_association_ids.adopted == "vpc-cidr-assoc-0123456789abcdef0" &&
      aws_subnet.main["adopted/us-east-1a"].cidr_block == "100.64.10.0/24"
    )
    error_message = "Injected secondary associations must omit resource creation and remain selectable by subnets."
  }
}

run "reject_secondary_with_two_sources" {
  command = plan

  variables {
    vpc = { name = "negative-test" }
    addressing = {
      primary = { cidr_block = "10.0.0.0/16" }
      secondary = {
        invalid = {
          ipv4 = {
            cidr_block     = "100.64.0.0/20"
            ipam_pool_id   = "ipam-pool-0123456789abcdef0"
            netmask_length = 20
          }
        }
      }
    }
    availability_zones = { names = ["us-east-1a"] }
    subnets            = {}
  }

  expect_failures = [var.addressing]
}

run "reject_unknown_secondary_selector" {
  command = plan

  variables {
    vpc                = { name = "negative-test" }
    addressing         = { primary = { cidr_block = "10.0.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = {
          cidrs_by_az        = { "us-east-1a" = "10.0.0.0/24" }
          secondary_cidr_key = "missing"
        }
      }
    }
  }

  expect_failures = [terraform_data.subnet_secondary_cidr_validation["app/us-east-1a"]]
}

run "reject_secondary_with_both_families" {
  command = plan

  variables {
    vpc = { name = "negative-test" }
    addressing = {
      primary = { cidr_block = "10.0.0.0/16" }
      secondary = {
        invalid = {
          ipv4 = { cidr_block = "100.64.0.0/20" }
          ipv6 = { amazon_assigned = true }
        }
      }
    }
    availability_zones = { names = ["us-east-1a"] }
  }

  expect_failures = [var.addressing]
}

run "calculated_ipv4_uses_selected_secondary_parent" {
  command = plan

  variables {
    vpc = { name = "secondary-calculation" }
    addressing = {
      primary = { cidr_block = "10.0.0.0/16" }
      secondary = {
        legacy = { ipv4 = { cidr_block = "100.64.0.0/20" } }
      }
    }
    availability_zones = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      primary = {
        role = "private"
        ipv4 = { netmask = 24, cidr_index = 0 }
      }
      legacy = {
        role = "private"
        ipv4 = { netmask = 24, cidr_index = 0, secondary_cidr_key = "legacy" }
      }
    }
  }

  assert {
    condition = (
      aws_subnet.main["primary/us-east-1a"].cidr_block == "10.0.0.0/24" &&
      aws_subnet.main["legacy/us-east-1a"].cidr_block == "100.64.0.0/24" &&
      aws_subnet.main["legacy/us-east-1b"].cidr_block == "100.64.1.0/24"
    )
    error_message = "Calculated IPv4 groups must allocate independently inside their selected primary or secondary parent."
  }
}

run "reject_explicit_ipv4_outside_selected_parent" {
  command = plan

  variables {
    vpc = { name = "secondary-containment" }
    addressing = {
      primary = { cidr_block = "10.0.0.0/16" }
      secondary = {
        blue  = { ipv4 = { cidr_block = "100.64.0.0/20" } }
        green = { ipv4 = { cidr_block = "100.65.0.0/20" } }
      }
    }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = {
          cidrs_by_az        = { us-east-1a = "100.65.0.0/24" }
          secondary_cidr_key = "blue"
        }
      }
    }
  }

  expect_failures = [terraform_data.subnet_secondary_cidr_validation["app/us-east-1a"]]
}

run "reject_duplicate_injected_ipv4_association" {
  command = plan

  variables {
    vpc = { name = "duplicate-injected-ipv4" }
    addressing = {
      primary = { cidr_block = "10.0.0.0/16" }
      secondary = {
        blue = {
          ipv4 = {
            create         = false
            association_id = "vpc-cidr-assoc-0123456789abcdef0"
          }
        }
        green = {
          ipv4 = {
            create         = false
            association_id = "vpc-cidr-assoc-0123456789abcdef0"
          }
        }
      }
    }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      blue = {
        role = "private"
        ipv4 = { netmask = 24, cidr_index = 0, secondary_cidr_key = "blue" }
      }
      green = {
        role = "private"
        ipv4 = { netmask = 24, cidr_index = 0, secondary_cidr_key = "green" }
      }
    }
  }

  expect_failures = [var.addressing]
}

run "subnet_ipv4_ipam_selector_preserves_separate_pool" {
  command = plan

  variables {
    vpc = { name = "subnet-ipam-selector" }
    addressing = {
      primary = { cidr_block = "10.30.0.0/16" }
      secondary = {
        blue = { ipv4 = { ipam_pool_id = "ipam-pool-vpc-blue", netmask_length = 20 } }
      }
    }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = {
          secondary_cidr_key = "blue"
          ipam_pool_id       = "ipam-pool-subnet-child"
          netmask_length     = 24
        }
      }
    }
  }

  assert {
    condition = (
      terraform_data.subnet_secondary_cidr_validation["app/us-east-1a"].input == aws_vpc_ipv4_cidr_block_association.secondary["blue"].id &&
      aws_subnet.main["app/us-east-1a"].ipv4_ipam_pool_id == "ipam-pool-subnet-child"
    )
    error_message = "IPv4 subnet IPAM must retain the selected association dependency without pretending the subnet pool ID equals its VPC parent pool."
  }
}

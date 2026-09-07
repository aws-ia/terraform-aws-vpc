mock_provider "aws" {
  override_during = plan

  mock_resource "aws_vpc" {
    defaults = {
      id         = "vpc-mock"
      arn        = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-mock"
      cidr_block = "10.80.0.0/16"
    }
  }

  mock_resource "aws_subnet" {
    defaults = { id = "subnet-mock" }
  }

  mock_resource "aws_network_acl" {
    defaults = { id = "acl-created" }
  }
}

run "create_inject_rules_and_associations" {
  command = plan

  variables {
    vpc                = { name = "nacl-test" }
    addressing         = { primary = { cidr_block = "10.80.0.0/16" } }
    availability_zones = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = { cidrs_by_az = { "us-east-1a" = "10.80.0.0/24", "us-east-1b" = "10.80.1.0/24" } }
        network_acl = {
          ingress = {
            "200" = {
              protocol   = "tcp"
              action     = "deny"
              cidr_block = "198.51.100.0/24"
              from_port  = 443
              to_port    = 443
            }
            "100" = {
              protocol   = "tcp"
              action     = "allow"
              cidr_block = "10.80.0.0/16"
              from_port  = 443
              to_port    = 443
            }
          }
          egress = {
            "100" = {
              protocol   = "tcp"
              action     = "allow"
              cidr_block = "10.80.0.0/16"
              from_port  = 1024
              to_port    = 65535
            }
          }
        }
      }
      data = {
        role = "private"
        ipv4 = { cidrs_by_az = { "us-east-1a" = "10.80.2.0/24", "us-east-1b" = "10.80.3.0/24" } }
        network_acl = {
          create = false
          id     = "acl-injected"
          ingress = {
            "110" = {
              protocol        = "icmpv6"
              action          = "allow"
              ipv6_cidr_block = "2001:db8::/64"
              icmp_type       = -1
              icmp_code       = -1
            }
          }
        }
      }
    }
  }

  assert {
    condition = (
      length(aws_network_acl.this) == 1 &&
      output.network_acl_ids_by_group == {
        app  = "acl-created"
        data = "acl-injected"
      }
    )
    error_message = "Per-group NACLs must support one created ACL and one injected ACL identity."
  }

  assert {
    condition = toset(keys(aws_network_acl_rule.this)) == toset([
      "app/ingress/100",
      "app/ingress/200",
      "app/egress/100",
      "data/ingress/110",
    ])
    error_message = "NACL rules must be keyed by group, direction, and explicit rule number independent of declaration order."
  }

  assert {
    condition = toset(keys(aws_network_acl_association.this)) == toset([
      "app/us-east-1a",
      "app/us-east-1b",
      "data/us-east-1a",
      "data/us-east-1b",
    ])
    error_message = "Every subnet in a configured group must receive one stable NACL association."
  }
}

run "omit_network_acl_preserves_default_behavior" {
  command = plan

  variables {
    vpc                = { name = "default-nacl" }
    addressing         = { primary = { cidr_block = "10.81.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = { cidrs_by_az = { "us-east-1a" = "10.81.0.0/24" } }
      }
    }
  }

  assert {
    condition = (
      length(aws_network_acl.this) == 0 &&
      length(aws_network_acl_rule.this) == 0 &&
      length(aws_network_acl_association.this) == 0 &&
      length(output.network_acl_ids_by_group) == 0
    )
    error_message = "Omitting network_acl must preserve current default-NACL behavior and create no NACL resources."
  }
}

run "reject_invalid_network_acl_rule_number" {
  command = plan

  variables {
    vpc                = { name = "invalid-number" }
    addressing         = { primary = { cidr_block = "10.82.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = { cidrs_by_az = { "us-east-1a" = "10.82.0.0/24" } }
        network_acl = {
          ingress = {
            "0100" = { protocol = "-1", action = "allow", cidr_block = "0.0.0.0/0" }
          }
        }
      }
    }
  }

  expect_failures = [var.subnets]
}

run "reject_invalid_network_acl_rule_fields" {
  command = plan

  variables {
    vpc                = { name = "invalid-rule" }
    addressing         = { primary = { cidr_block = "10.83.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = { cidrs_by_az = { "us-east-1a" = "10.83.0.0/24" } }
        network_acl = {
          ingress = {
            "100" = {
              protocol        = "999"
              action          = "accept"
              cidr_block      = "not-a-cidr"
              ipv6_cidr_block = "2001:db8::/64"
              from_port       = 65535
              to_port         = 1
              icmp_type       = 999
            }
          }
        }
      }
    }
  }

  expect_failures = [var.subnets]
}

run "reject_invalid_network_acl_injection" {
  command = plan

  variables {
    vpc                = { name = "invalid-injection" }
    addressing         = { primary = { cidr_block = "10.84.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = { cidrs_by_az = { "us-east-1a" = "10.84.0.0/24" } }
        network_acl = {
          create = false
          id     = ""
        }
      }
    }
  }

  expect_failures = [var.subnets]
}

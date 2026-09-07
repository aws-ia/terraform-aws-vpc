mock_provider "aws" {
  override_during = plan

  mock_resource "aws_vpc" {
    defaults = {
      id         = "vpc-documentation"
      arn        = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-documentation"
      cidr_block = "10.100.0.0/16"
    }
  }
  mock_resource "aws_subnet" {
    defaults = {
      id  = "subnet-documentation"
      arn = "arn:aws:ec2:us-east-1:123456789012:subnet/subnet-documentation"
    }
  }
  mock_resource "aws_route_table" {
    defaults = { id = "rtb-documentation" }
  }
  mock_resource "aws_ec2_transit_gateway_vpc_attachment" {
    defaults = { id = "tgw-attach-created" }
  }
}

variables {
  vpc                = { name = "plural-tgw-test" }
  addressing         = { primary = { cidr_block = "10.100.0.0/16" } }
  availability_zones = { names = ["us-east-1a"] }
  subnets = {
    app = {
      role = "private"
      ipv4 = { cidrs_by_az = { us-east-1a = "10.100.0.0/24" } }
      routing = {
        transit_gateway_attachments = {
          east = ["10.101.0.0/16"]
          west = ["10.102.0.0/16"]
        }
      }
    }
    tgw = {
      role = "transit_gateway"
      ipv4 = { cidrs_by_az = { us-east-1a = "10.100.1.0/28" } }
    }
  }
  transit_gateway_attachments = {
    east = {
      subnet_group = "tgw"
      id           = "tgw-00000000000000001"
      create       = true
    }
    west = {
      subnet_group = "tgw"
      id           = "tgw-00000000000000002"
      create       = true
    }
  }
}

run "create_create" {
  command = plan

  assert {
    condition = (
      toset(keys(aws_ec2_transit_gateway_vpc_attachment.this)) == toset(["east", "west"]) &&
      toset(keys(output.transit_gateway_attachment_ids)) == toset(["east", "west"]) &&
      output.transit_gateway_attachment_ids.east == "tgw-attach-created" &&
      output.transit_gateway_attachment_ids.west == "tgw-attach-created"
    )
    error_message = "Two created TGW attachments must retain their caller-owned keys in resources and outputs."
  }

  assert {
    condition = (
      length(aws_route.tgw_attachment) == 2 &&
      aws_route.tgw_attachment["app/us-east-1a/tgw/east/10.101.0.0-16"].transit_gateway_id == "tgw-00000000000000001" &&
      aws_route.tgw_attachment["app/us-east-1a/tgw/west/10.102.0.0-16"].transit_gateway_id == "tgw-00000000000000002"
    )
    error_message = "Plural routes must select the Transit Gateway ID of their attachment key."
  }
}

run "create_inject" {
  command = plan

  variables {
    transit_gateway_attachments = {
      east = {
        subnet_group = "tgw"
        id           = "tgw-00000000000000001"
        create       = true
      }
      west = {
        subnet_group  = "tgw"
        id            = "tgw-00000000000000002"
        create        = false
        attachment_id = "tgw-attach-injected-west"
      }
    }
  }

  assert {
    condition = (
      toset(keys(aws_ec2_transit_gateway_vpc_attachment.this)) == toset(["east"]) &&
      output.transit_gateway_attachment_ids.east == "tgw-attach-created" &&
      output.transit_gateway_attachment_ids.west == "tgw-attach-injected-west"
    )
    error_message = "Create/inject ownership must create only east and preserve west's injected ID."
  }
}

run "inject_create" {
  command = plan

  variables {
    transit_gateway_attachments = {
      east = {
        subnet_group  = "tgw"
        id            = "tgw-00000000000000001"
        create        = false
        attachment_id = "tgw-attach-injected-east"
      }
      west = {
        subnet_group = "tgw"
        id           = "tgw-00000000000000002"
        create       = true
      }
    }
  }

  assert {
    condition = (
      toset(keys(aws_ec2_transit_gateway_vpc_attachment.this)) == toset(["west"]) &&
      output.transit_gateway_attachment_ids.east == "tgw-attach-injected-east" &&
      output.transit_gateway_attachment_ids.west == "tgw-attach-created"
    )
    error_message = "Inject/create ownership must create only west and preserve east's injected ID."
  }
}

run "inject_inject" {
  command = plan

  variables {
    transit_gateway_attachments = {
      east = {
        subnet_group  = "tgw"
        id            = "tgw-00000000000000001"
        create        = false
        attachment_id = "tgw-attach-injected-east"
      }
      west = {
        subnet_group  = "tgw"
        id            = "tgw-00000000000000002"
        create        = false
        attachment_id = "tgw-attach-injected-west"
      }
    }
  }

  assert {
    condition = (
      length(aws_ec2_transit_gateway_vpc_attachment.this) == 0 &&
      output.transit_gateway_attachment_ids == {
        east = "tgw-attach-injected-east"
        west = "tgw-attach-injected-west"
      }
    )
    error_message = "Fully injected ownership must create no attachments and return both effective IDs."
  }
}

run "legacy_adapter_preserves_vpc_key" {
  command = plan

  variables {
    subnets = {
      tgw = {
        role = "transit_gateway"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.100.1.0/28" } }
        transit_gateway_options = {
          id     = "tgw-00000000000000001"
          create = true
        }
      }
    }
    transit_gateway_attachments = {}
  }

  assert {
    condition = (
      toset(keys(aws_ec2_transit_gateway_vpc_attachment.this)) == toset(["vpc"]) &&
      toset(keys(output.transit_gateway_attachment_ids)) == toset(["vpc"]) &&
      output.transit_gateway_attachment_id == "tgw-attach-created"
    )
    error_message = "The deprecated singular adapter must preserve resource key 'vpc' and its scalar output."
  }
}

run "reject_same_destination_for_two_attachments" {
  command = plan

  variables {
    subnets = {
      app = {
        role = "private"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.100.0.0/24" } }
        routing = {
          transit_gateway_attachments = {
            east = ["10.103.0.0/16"]
            west = ["10.103.0.0/16"]
          }
        }
      }
      tgw = {
        role = "transit_gateway"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.100.1.0/28" } }
      }
    }
    transit_gateway_attachments = {
      east = {
        subnet_group  = "tgw"
        id            = "tgw-00000000000000001"
        create        = false
        attachment_id = "tgw-attach-injected-east"
      }
      west = {
        subnet_group  = "tgw"
        id            = "tgw-00000000000000002"
        create        = false
        attachment_id = "tgw-attach-injected-west"
      }
    }
  }

  expect_failures = [terraform_data.route_table_routing_compatibility_validation]
}

run "reject_duplicate_transit_gateway_id" {
  command = plan

  variables {
    transit_gateway_attachments = {
      east = {
        subnet_group  = "tgw"
        id            = "tgw-00000000000000001"
        create        = false
        attachment_id = "tgw-attach-injected-east"
      }
      duplicate = {
        subnet_group  = "tgw"
        id            = "tgw-00000000000000001"
        create        = false
        attachment_id = "tgw-attach-injected-duplicate"
      }
    }
  }

  expect_failures = [var.transit_gateway_attachments]
}

run "reject_multiple_legacy_adapters" {
  command = plan

  variables {
    subnets = {
      tgw_east = {
        role = "transit_gateway"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.100.1.0/28" } }
        transit_gateway_options = {
          id     = "tgw-00000000000000001"
          create = true
        }
      }
      tgw_west = {
        role = "transit_gateway"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.100.2.0/28" } }
        transit_gateway_options = {
          id     = "tgw-00000000000000002"
          create = true
        }
      }
    }
    transit_gateway_attachments = {}
  }

  expect_failures = [var.subnets]
}

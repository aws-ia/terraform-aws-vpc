mock_provider "aws" {
  override_during = plan

  mock_data "aws_region" {
    defaults = { region = "us-east-1" }
  }

  mock_resource "aws_vpc" {
    defaults = {
      id         = "vpc-mock"
      arn        = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-mock"
      cidr_block = "10.70.0.0/16"
    }
  }

  mock_resource "aws_subnet" {
    defaults = { id = "subnet-mock" }
  }

  mock_resource "aws_route_table" {
    defaults = { id = "rtb-managed" }
  }

  mock_resource "aws_vpc_endpoint" {
    defaults = { id = "vpce-created-s3" }
  }
}

run "create_inject_and_associate_gateway_endpoints" {
  command = plan

  variables {
    vpc                = { name = "endpoint-test" }
    addressing         = { primary = { cidr_block = "10.70.0.0/16" } }
    availability_zones = { names = ["us-east-1a", "us-east-1b"] }
    subnets = {
      app = {
        role = "private"
        ipv4 = { cidrs_by_az = { "us-east-1a" = "10.70.0.0/24", "us-east-1b" = "10.70.1.0/24" } }
        routing = {
          s3_gateway_endpoint       = true
          dynamodb_gateway_endpoint = true
        }
      }
      shared = {
        role               = "private"
        ipv4               = { cidrs_by_az = { "us-east-1a" = "10.70.2.0/24", "us-east-1b" = "10.70.3.0/24" } }
        manage_route_table = false
        route_table_key    = "shared"
        route_table_id     = "rtb-shared"
        routing            = { s3_gateway_endpoint = true }
      }
    }
    gateway_endpoints = {
      s3 = {
        service = "s3"
        policy  = jsonencode({ Version = "2012-10-17", Statement = [] })
      }
      ddb-shared = {
        service     = "dynamodb"
        create      = false
        endpoint_id = "vpce-existing-ddb"
      }
    }
  }

  assert {
    condition = (
      length(aws_vpc_endpoint.gateway) == 1 &&
      aws_vpc_endpoint.gateway["s3"].service_name == "com.amazonaws.us-east-1.s3" &&
      jsondecode(aws_vpc_endpoint.gateway["s3"].policy).Version == "2012-10-17" &&
      output.gateway_endpoint_ids == {
        s3         = "vpce-created-s3"
        ddb-shared = "vpce-existing-ddb"
      }
    )
    error_message = "Gateway endpoints must support one created S3 endpoint, one injected DynamoDB endpoint, and optional JSON policy."
  }

  assert {
    condition = toset(keys(aws_vpc_endpoint_route_table_association.gateway)) == toset([
      "app/us-east-1a/gateway-endpoint/s3",
      "app/us-east-1b/gateway-endpoint/s3",
      "app/us-east-1a/gateway-endpoint/dynamodb",
      "app/us-east-1b/gateway-endpoint/dynamodb",
      "injected/shared/gateway-endpoint/s3",
    ])
    error_message = "Endpoint associations must use stable service/group/route-table keys and de-duplicate injected shared route tables."
  }
}

run "reject_duplicate_gateway_endpoint_service" {
  command = plan

  variables {
    vpc                = { name = "duplicate-endpoint" }
    addressing         = { primary = { cidr_block = "10.71.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets            = {}
    gateway_endpoints = {
      primary = { service = "s3" }
      backup  = { service = "s3" }
    }
  }

  expect_failures = [var.gateway_endpoints]
}

run "reject_invalid_gateway_endpoint_policy" {
  command = plan

  variables {
    vpc                = { name = "invalid-policy" }
    addressing         = { primary = { cidr_block = "10.72.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets            = {}
    gateway_endpoints = {
      s3 = { service = "s3", policy = "not-json" }
    }
  }

  expect_failures = [var.gateway_endpoints]
}

run "reject_gateway_endpoint_route_without_endpoint" {
  command = plan

  variables {
    vpc                = { name = "missing-endpoint" }
    addressing         = { primary = { cidr_block = "10.73.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      app = {
        role    = "private"
        ipv4    = { cidrs_by_az = { "us-east-1a" = "10.73.0.0/24" } }
        routing = { s3_gateway_endpoint = true }
      }
    }
  }

  expect_failures = [terraform_data.gateway_endpoint_routing_validation[0]]
}


run "isolated_groups_allow_private_gateway_endpoints" {
  command = plan

  variables {
    vpc                = { name = "isolated-endpoints" }
    addressing         = { primary = { cidr_block = "10.74.0.0/16" } }
    availability_zones = { names = ["us-east-1a"] }
    subnets = {
      data = {
        role = "isolated"
        ipv4 = { cidrs_by_az = { us-east-1a = "10.74.0.0/24" } }
        routing = {
          s3_gateway_endpoint       = true
          dynamodb_gateway_endpoint = true
        }
      }
    }
    gateway_endpoints = {
      s3       = { service = "s3" }
      dynamodb = { service = "dynamodb" }
    }
  }

  assert {
    condition = (
      length(aws_vpc_endpoint.gateway) == 2 &&
      length(aws_vpc_endpoint_route_table_association.gateway) == 2 &&
      length(aws_internet_gateway.main) == 0 &&
      length(aws_nat_gateway.main) == 0 &&
      length(aws_egress_only_internet_gateway.main) == 0
    )
    error_message = "Isolated groups must allow private S3/DynamoDB gateway routes without creating Internet egress resources."
  }
}

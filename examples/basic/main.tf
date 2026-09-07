module "vpc" {
  source = "../.."

  vpc = {
    name = "web-app-vpc"
  }

  addressing = {
    primary = { cidr_block = "10.0.0.0/16" }
    secondary = {
      amazon-ipv6 = { ipv6 = { amazon_assigned = true } }
    }
  }

  availability_zones = { count = 3 }

  subnets = {
    public = {
      role = "public"
      ipv4 = { netmask = 24 }
      ipv6 = { secondary_cidr_key = "amazon-ipv6", auto_assign = true }
      routing = {
        internet_gateway = true
      }
      public_options = {
        map_public_ip = true
      }
    }

    app = {
      role = "private"
      ipv4 = { netmask = 22 }
      ipv6 = { secondary_cidr_key = "amazon-ipv6", auto_assign = true }
      routing = {
        nat_gateway               = true
        egress_only_igw           = true
        dns64                     = true
        s3_gateway_endpoint       = true
        dynamodb_gateway_endpoint = true
      }
    }

    database = {
      role = "isolated"
      ipv4 = { netmask = 24 }
    }
  }

  nat_gateway = {
    mode         = "single_az"
    az           = "us-east-1a"
    subnet_group = "public"
  }

  gateway_endpoints = {
    s3 = { service = "s3" }
    dynamodb = {
      service = "dynamodb"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect    = "Allow"
          Principal = "*"
          Action = [
            "dynamodb:BatchGetItem",
            "dynamodb:BatchWriteItem",
            "dynamodb:ConditionCheckItem",
            "dynamodb:DeleteItem",
            "dynamodb:DescribeTable",
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:Query",
            "dynamodb:Scan",
            "dynamodb:UpdateItem",
          ]
          Resource = [
            "arn:aws:dynamodb:us-east-1:123456789012:table/application-data",
            "arn:aws:dynamodb:us-east-1:123456789012:table/application-data/index/*",
          ]
        }]
      })
    }
  }

  # Native CloudWatch destination and VPC Flow Logs IAM role are created.
  flow_logs = {
    audit = {
      destination_type = "cloudwatch"
      traffic_type     = "ALL"
      cloudwatch_options = {
        retention_in_days = 30
      }
    }
  }

  tags = {
    Environment = "development"
    Project     = "web-app"
  }
}

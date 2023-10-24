
# VPC module
module "vpc" {
  source = "../.."

  name       = "tgw"
  cidr_block = "10.0.0.0/24"
  az_count   = 2

  vpc_lattice = {
    service_network_identifier = aws_vpclattice_service_network.service_network.id
    security_group_ids         = [aws_security_group.security_group.id]
    tags = {
      vpc_lattice = true
    }
  }

  subnets = {
    workload = { netmask = 28 }
  }

  tags = {
    vpc_module = true
  }
}

# VPC Lattice Service Network
resource "aws_vpclattice_service_network" "service_network" {
  name      = "example-service-network"
  auth_type = "NONE"
}

# Security Group
resource "aws_security_group" "security_group" {
  name        = "lattice-sg"
  description = "Lattice Securigy Group."
  vpc_id      = module.vpc.vpc_attributes.id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/24"]
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/24"]
  }

  egress {
    description = "Allowing inter-VPC traffic."
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/24"]
  }

  egress {
    description = "Allowing VPC Lattice traffic."
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["169.254.171.0/24"]
  }
}






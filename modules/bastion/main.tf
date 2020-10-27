terraform {
  required_version = ">= 0.13"

}


data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = ["${var.name}_vpc"]
  }
}

data "aws_subnet_ids" "private" {
  vpc_id = data.aws_vpc.vpc.id
filter {
    name   = "tag:Name"
    values = ["${var.name}_public_subnets"] 
  }
}

data "aws_security_groups" "public" {
   filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }
  filter {
    name   = "group-name"
    values = ["default"] 
  }
}

data "aws_security_group" "public" {
   filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }
  filter {
    name   = "group-name"
    values = ["default"] 
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name = "name"

    values = [
      "amzn-ami-hvm-*-x86_64-gp2",
    ]
  }

  filter {
    name = "owner-alias"

    values = [
      "amazon",
    ]
  }
}

resource "random_id" "name" {
  byte_length = 4
  prefix      = "tls-private-key-"
}

resource "tls_private_key" "key" {
  algorithm   = "RSA"
  rsa_bits    = "2048"
}

resource "aws_key_pair" "main" {
  key_name_prefix = random_id.name.hex
  public_key      = tls_private_key.key.public_key_openssh
}

resource "aws_security_group_rule" "ssh" {
  count = var.create_bastion ? 1 : 0
  type              = "ingress"
  from_port         = 0
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = data.aws_security_group.public.id
}


resource "aws_launch_template" "bastion" {

  name_prefix   = "bastion"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  vpc_security_group_ids = data.aws_security_groups.public.ids
  key_name = var.key_name == ""  ? aws_key_pair.main.id : var.key_name
}
resource "aws_autoscaling_group" "bastion" {
  count = var.create_bastion ? 1 : 0
  vpc_zone_identifier  = data.aws_subnet_ids.private.ids
  desired_capacity   = 2
  max_size           = 5
  min_size           = 2

  launch_template {
    id      = aws_launch_template.bastion.id
    version = "$Latest"
  }
}

output "private_key_pem" {
  value = tls_private_key.key.private_key_pem
}
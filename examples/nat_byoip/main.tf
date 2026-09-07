locals {
  subnet_groups = {
    public = {
      role = "public"
      ipv4 = { netmask = 24 }
    }
    application = {
      role    = "private"
      ipv4    = { netmask = 24 }
      routing = { nat_gateway = true }
    }
  }

  regional_subnet_groups = {
    application = {
      role    = "private"
      ipv4    = { netmask = 24 }
      routing = { nat_gateway = true }
    }
  }
}

module "create" {
  source = "../.."

  vpc                = { name = "nat-eip-create" }
  addressing         = { primary = { cidr_block = "10.10.0.0/16" } }
  availability_zones = { names = var.availability_zones }
  subnets            = local.subnet_groups

  nat_gateway = {
    mode         = "all_azs"
    subnet_group = "public"
    eip          = { mode = "create" }
  }
}

module "byoip_pool" {
  source = "../.."

  vpc                = { name = "nat-eip-byoip" }
  addressing         = { primary = { cidr_block = "10.20.0.0/16" } }
  availability_zones = { names = var.availability_zones }
  subnets            = local.subnet_groups

  nat_gateway = {
    mode         = "all_azs"
    subnet_group = "public"
    eip = {
      mode             = "byoip_pool"
      public_ipv4_pool = var.public_ipv4_pool
    }
  }
}

module "existing" {
  source = "../.."

  vpc                = { name = "nat-eip-existing" }
  addressing         = { primary = { cidr_block = "10.30.0.0/16" } }
  availability_zones = { names = var.availability_zones }
  subnets            = local.subnet_groups

  nat_gateway = {
    mode         = "all_azs"
    subnet_group = "public"
    eip = {
      mode           = "existing"
      allocation_ids = var.existing_eip_allocation_ids
    }
  }
}

module "regional_existing" {
  source = "../.."

  vpc                = { name = "nat-regional-existing" }
  addressing         = { primary = { cidr_block = "10.40.0.0/16" } }
  availability_zones = { names = var.availability_zones }
  subnets            = local.regional_subnet_groups

  nat_gateway = {
    mode = "regional"
    eip = {
      mode           = "existing"
      allocation_ids = var.existing_eip_allocation_ids
    }
  }
}


terraform {
  required_version = ">= 1.0.0"
}
locals {
  dir_down = ".."
}

# Generate new terraform org and workspace

module "tfcloud" {
  source                = "aws-ia/cloud_workspace/hashicorp"
  version               = "0.0.2"
  tfe_email             = var.tfe_email
  tfe_organization      = var.tfe_organization
  tfe_workspace         = var.tfe_workspace
  AWS_ACCESS_KEY_ID     = var.AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY = var.AWS_SECRET_ACCESS_KEY
  AWS_SESSION_TOKEN     = var.AWS_SESSION_TOKEN
  working_directory     = var.working_directory
  region                = var.region
}


resource "null_resource" "setup_backend_file" {
  depends_on = [module.tfcloud]
  provisioner "local-exec" {
    command = "mv backend.hcl ${local.dir_down}${var.working_directory}"
  }
}


resource "null_resource" "remoteinit" {
  depends_on = [null_resource.setup_backend_file]
  provisioner "local-exec" {
    working_dir = "${local.dir_down}${var.working_directory}"
    command     = "terraform init -backend-config=backend.hcl"
  }
}

output "user_instructions" {
  value = <<README
# org name    = ${module.tfcloud.tfcloud-org-name}
# workspace   = ${module.tfcloud.tfcloud-workspace-name}


# Run these commands in order:
cd ${local.dir_down}${var.working_directory}

# Configure your tfvars file
  AWS_SECRET_ACCESS_KEY = "*****************"
  AWS_ACCESS_KEY_ID     = "*****************"
  AWS_SESSION_TOKEN     = "*****************"
  region                = ${var.region}

#  Note: Use of STS Creds are highly reccommended!
# !!!!CAUTION!!!!: Make sure your credentials are secured outside version control 
# (and follow secrets mangement bestpractices)
#   
   terraform apply  -var-file="$HOME/.aws/terraform.tfvars"
README
}

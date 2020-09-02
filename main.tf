###########
# pre-reqs
# terraform login
# export TERRAFORM_CONFIG=$HOME/.terraform.d/credentials.tfrc.json"
##########
terraform {
  required_version = ">= 0.13"

}

resource "random_pet" "name" {
  prefix = "aws-quickstart"
  length = 1
}

resource "tfe_organization" "quickstart-org" {
  name  = random_pet.name.id
  email = "admin@your-company.com"
}

resource "tfe_workspace" "quickstart-workspace" {
  name         = "${random_pet.name.id}-workspace"
  organization = tfe_organization.quickstart-org.name
}

resource  "null_resource" "backend_file" {
  depends_on = [tfe_workspace.quickstart-workspace]
  provisioner "local-exec" {
  command =  "echo  workspaces '{' name = \\\"${tfe_workspace.quickstart-workspace.name}\\\" '}' >> ./module/quickstart-vpc/backend.hcl"
  }
  provisioner "local-exec" {
  command =  "echo hostname = \\\"app.terraform.io\\\" >> ./module/quickstart-vpc/backend.hcl"
  }
  provisioner "local-exec" {
  command =  "echo  organization = \\\"${tfe_organization.quickstart-org.name}\\\" >> ./module/quickstart-vpc/backend.hcl"
  }
}

resource  "null_resource" "remote_init" {
  depends_on = [null_resource.backend_file]
  provisioner "local-exec" {
  working_dir = "./module/quickstart-vpc/"
  command =  "terraform init -backend-config=backend.hcl"
  }
}

output "User instructions" {
  value = <<README

# Run these commands in order:
# 1. cd ./module/quickstart-vpc
# 2. terraform apply
README
}

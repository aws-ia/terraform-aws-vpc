###########
# Defaults
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

resource "tfe_workspace" "quickstart-workspace-1" {
  name         = "${random_pet.name.id}-workspace-1"
  organization = tfe_organization.quickstart-org.name
  working_directory = "./deploy_new_vpc"
}
resource "tfe_variable" "AWS_SECRET_ACCESS_KEY" {
  key          = "AWS_SECRET_ACCESS_KEY"
  value        = ""
  sensitive    = true
  category     = "env"
  workspace_id = tfe_workspace.quickstart-workspace-1.id
  description  = "AWS_SECRET_ACCESS_KEY"
}
resource "tfe_variable" "AWS_ACCESS_KEY_ID" {
  key          = "AWS_ACCESS_KEY_ID"
  value        = ""
  category     = "env"
  workspace_id = tfe_workspace.quickstart-workspace-1.id
  description  = "AWS_ACCESS_KEY_ID"
}

resource  "null_resource" "backend_file" {
  depends_on = [tfe_workspace.quickstart-workspace-1]
  provisioner "local-exec" {
  command =  "echo  workspaces '{' name = \\\"${tfe_workspace.quickstart-workspace-1.name}\\\" '}' >> ../deploy_new_vpc/backend.hcl"
  }
  provisioner "local-exec" {
  command =  "echo hostname = \\\"app.terraform.io\\\" >> ../deploy_new_vpc/backend.hcl"
  }
  provisioner "local-exec" {
  command =  "echo  organization = \\\"${tfe_organization.quickstart-org.name}\\\" >> ../deploy_new_vpc/backend.hcl"
  }
}

resource  "null_resource" "remote_init" {
  depends_on = [null_resource.backend_file]
  provisioner "local-exec" {
  working_dir = "../deploy_new_vpc"
  command =  "terraform init -backend-config=backend.hcl"
  }
}

output "user_instructions" {
  value = <<README

 your org name        = ${tfe_organization.quickstart-org.name}
 your workspace for new vpc is      = ${tfe_workspace.quickstart-workspace-1.name}
your workspace for existing vpc is  = ${tfe_workspace.quickstart-workspace-2.name}
# Run these commands in order:
#    cd ../deploy_new_vpc
#then
#    terraform apply
README
}

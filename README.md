# tf-quickstart-amazon-vpc
# Step 1
## pre-reqs:

To deploy this quickstart you need to
1. git clone this directory
2. signup for Terraform Cloud (there is a free tier)

# Step 2

in the main directory perform the following commands:

terraform login

terrafrom init

terrafrom apply

# Step 3

# Run these commands in order:

 1. terraform output | cut -d '=' -f 2 >> ./VPC/backend.hcl.json

## Then to create your VPC run these commands:

 2. cd ./VPC
 3. terraform init -backend-config=backend.hcl.json
 4. apply your AWS key and Secrets key to the terraform workspace created in step 1
 5. terraform apply to deploy your VPC


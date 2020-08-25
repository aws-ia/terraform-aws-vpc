# tf-quickstart-amazon-vpc

git clone this directory

# Step 1

in the main directory perform the following commnads 

terrafrom init

terrafrom apply

# Step 2

# Run these commands in order:
#
# 1. terraform output | cut -d '=' -f 2 >> ./VPC/backend.hcl.json
#
# Then to create your VPC run these commands:
#
# 2. cd ./VPC
# 3. terraform init -backend-config=backend.hcl.json
# 4. apply your AWS key and Secrets key to the terraform workspace created in step 1
# 5. terraform apply to deploy your VPC


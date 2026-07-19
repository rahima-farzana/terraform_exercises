#---------------------------------------------#
# Author: Adam WezvaTechnologies
# Call/Whatsapp: +91-9739110917
#---------------------------------------------#

provider "aws" {
  region = "ap-south-1"
}

module "iam_roles" {
  source               = "../../modules/iam_roles"
  account_id           =  var.account_id # The ID of this Product account
  enable_product_role  = true           # Enable Dev and CI/CD roles here
  enable_cicd_role     = true
  env_type            = "prod"
}


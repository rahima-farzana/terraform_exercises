#---------------------------------------------#
# Author: Adam WezvaTechnologies
# Call/Whatsapp: +91-9739110917
#---------------------------------------------#

provider "aws" {
  region = "ap-south-1"
}

module "iam_roles" {
  source               = "../../modules/iam_roles"
  account_id           = var.account_id # The ID of this ops account
  enable_platform_role = true           # Only enable the Admin/Guardian roles here
  env_type             = "platform"
}


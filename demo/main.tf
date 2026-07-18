# ------------------------------------------------------------------- #
# Use this project to provision Test EC2 servers
# Map variable defines the details of each server you are provisioning
#    Name/Tag of the server = Type of the server
# AUTHOR: ADAM M | +91-9739110917 
# ------------------------------------------------------------------- #

provider "aws" {
  region = "ap-south-1"
}

variable "myhosts" {
  type = map
  default = {
    TESTMACHINE = "t2.micro"
  }
}

variable "mykey" { 
  default = "wezva2026"
}

module "server" {
  for_each = var.myhosts
  servername = each.key
  type = each.value  
  pemfile = var.mykey
  source = "../instances"
}


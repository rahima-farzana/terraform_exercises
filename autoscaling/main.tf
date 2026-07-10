
#---------------------------------------------#
# Author: Adam WezvaTechnologies
# Call/Whatsapp: +91-9739110917
#---------------------------------------------#

provider "aws" {
  region = "ap-south-1"
}

module "autoscaling" {
  source = "./autoscaling"
  name = "asg-blue"
  create_launch_template = true
  vpc_zone_identifier       = ["subnet-08e8146d5754843f7", "subnet-0085f77c1a13eb36c", "subnet-0ad5ec3834e796e0d"]
  # Base64 encode the shell script text payload 
  user_data = base64encode(file("./autoscaling/neo4j-bootstrap.sh"))

#  load_balancers            = ["wezvatech"]
  min_size                  = 1
  max_size                  = 3
  desired_capacity          = 1

  launch_template_name        = "lt-blue"
  image_id          = "ami-01a00762f46d584a1"
  key_name          = "wezva2026"
  instance_type     = "t3.medium"
  security_groups   = ["sg-0a7e1529fed5652fe"]
}

#---------------------------------------------#
# Author: Adam WezvaTechnologies
# Call/Whatsapp: +91-9739110917
#---------------------------------------------#

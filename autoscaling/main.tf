
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
  vpc_zone_identifier       = ["subnet-034ae6bc268a8a248", "subnet-0d4876621a535c5f1", "subnet-06ae91a8b23fe0ce6"]
  load_balancers            = ["wezvatech"]
  min_size                  = 1
  max_size                  = 2
  desired_capacity          = 1
  health_check_type         = "EC2"
  health_check_grace_period = 30

  launch_template_name        = "lt-blue"
  image_id          = "ami-0836ed1f613068bd6"
  key_name          = "wezva2025"
  instance_type     = "t3.micro"
  security_groups   = ["sg-0a781bd43a7ce089e"]
}

#---------------------------------------------#
# Author: Adam WezvaTechnologies
# Call/Whatsapp: +91-9739110917
#---------------------------------------------#

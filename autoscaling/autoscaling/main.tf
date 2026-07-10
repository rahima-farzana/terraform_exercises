
#---------------------------------------------#
# Author: Adam WezvaTechnologies
# Call/Whatsapp: +91-9739110917
#---------------------------------------------#

data "aws_availability_zones" "all" {}

resource "aws_launch_template" "demo" {
  count = var.create_launch_template ? 1 : 0

  name          = var.launch_template_name
  image_id      = var.image_id
  key_name      = var.key_name
  user_data     = var.user_data
  instance_type = var.instance_type

  vpc_security_group_ids = var.security_groups

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Enforces IMDSv2 securely
    http_put_response_hop_limit = 2          # FIXES THE CRASH BY ALLOWING CROSS-BRIDGE PACKETS
  }

  # Add High-Performance Persistent Storage for Neo4j Graph Data
  block_device_mappings {
    device_name = "/dev/xvda" # Root volume
    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  block_device_mappings {
    device_name = "/dev/sdb" # Dedicated high-IOPS data disk for Neo4j transactional engine
    ebs {
      volume_size           = 100 # Adjust based on data volume
      volume_type           = "gp3"
      iops                  = 3000
      throughput            = 125
      encrypted             = true # Strict FinTech encryption at rest
      delete_on_termination = false # Prevents data loss during ASG instance replacement!
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "demo" {
  vpc_zone_identifier       = var.vpc_zone_identifier
  max_size                  = var.max_size
  min_size                  = var.min_size
  desired_capacity          = var.desired_capacity
  health_check_grace_period = var.health_check_grace_period
  health_check_type         = var.health_check_type
  force_delete              = false # Never force-delete stateful database cluster pools

  instance_maintenance_policy {
    min_healthy_percentage = 66  # Allows 1 node of a 3-node cluster to update safely
    max_healthy_percentage = 100
  }


  launch_template {
    id      = aws_launch_template.demo[0].id
    version = "$Latest"
  }

  tag {
    key                 = "Role"
    value               = "FinTech-Neo4j-Cluster"
    propagate_at_launch = true
  }
}



#---------------------------------------------#
# Author: Adam WezvaTechnologies
# Call/Whatsapp: +91-9739110917
#---------------------------------------------#


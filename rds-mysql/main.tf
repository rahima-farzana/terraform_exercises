
data "aws_vpc" "default" {
  default = true
}

provider "aws" {
    region     = var.aws_region
}

resource "aws_security_group" "rds_sg" {
  name = "rds_sg"
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#- Create Blue DB Instance -#
resource "aws_db_instance" "blue" {
  count = var.delete_source_db ? 0 : 1

  engine                 = "mysql"
  db_name                = "mywezvadb"
  identifier             = "wezvadb-main-blue" # Identifier for the initial BLUE instance
  instance_class         = "db.t3.micro"
  engine_version         = "8.0.41"
  allocated_storage      = 20
  publicly_accessible    = true
  username               = "admin"
  password               = "wezvatech"
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  backup_retention_period = 7 
  skip_final_snapshot    = true
  tags = {
    Environment = "Blue"
  }
}

#- Create Green DB Instance -#
resource "aws_db_instance" "green" {
  count                  = var.trigger_green_creation ? 1 : 0

  engine                 = "mysql"
  identifier             = "wezvadb-main-green" # Identifier for the initial GREEN instance
  instance_class         = var.target_instance_type
  engine_version         = var.target_db_engine_version
  allocated_storage      = 20
  publicly_accessible    = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true

  #replicate_source_db    = "wezvadb-main-blue"
  allow_major_version_upgrade = true
  snapshot_identifier    = "wezvadb-main-blue-manual-snapshot"
  depends_on = [null_resource.create_snapshot[0]]

  tags = {
    Environment = "Green"
  }
}

#- Create a latest snapshot of Blue DB -#
resource "null_resource" "create_snapshot" {
  count     = var.trigger_green_creation ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      echo "Requesting snapshot creation..."
      aws rds create-db-snapshot --db-instance-identifier wezvadb-main-blue --db-snapshot-identifier wezvadb-main-blue-manual-snapshot
      echo "Waiting for snapshot to become available (this might take several minutes)..."
      aws rds wait db-snapshot-available --db-snapshot-identifier wezvadb-main-blue-manual-snapshot
      echo "Snapshot is available. Proceeding with green DB creation."
    EOT
  }

}

#- Delete the snapshot of Blue DB -#
resource "null_resource" "delete_snapshot" {
   count     = var.delete_source_db ? 1 : 0

   provisioner "local-exec" {
     command = "aws rds delete-db-snapshot --db-snapshot-identifier wezvadb-main-blue-manual-snapshot"
   }
}

#- Route 53 Private Hosted Zone for testing -#
resource "aws_route53_zone" "private_test_zone" {
  name = "wezvatech-9739110917.internal" 
  
  vpc {
    vpc_id = data.aws_vpc.default.id
  }
}

#- Create DNS record for DB -#
resource "aws_route53_record" "db" {
  zone_id = aws_route53_zone.private_test_zone.zone_id
  name    = "prod.db.wezva.com"
  type    = "CNAME"
  ttl     = 300

  records = [
     var.trigger_switchover ? aws_db_instance.green[0].address : aws_db_instance.blue[0].address
  ]
}

# 1. Automatically find your default VPC and public subnets
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Force the default VPC to turn on DNS Hostnames so it can resolve MSK Serverless domains
resource "aws_default_vpc" "default" {
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# 2. Security Group for Serverless MSK
resource "aws_security_group" "msk_demo_sg" {
  name        = "msk-serverless-demo-sg"
  description = "Allow Kafka and Monitoring traffic"
  vpc_id      = data.aws_vpc.default.id

  # Kafka IAM SASL Port for MSK Serverless
  ingress {
    from_port   = 9098
    to_port     = 9098
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

# 3. MSK Serverless Cluster Configuration (Ultra Quick)
resource "aws_msk_serverless_cluster" "demo_msk" {
  cluster_name = "fintech-demo-cluster"

  vpc_config {
    subnet_ids         = slice(data.aws_subnets.public.ids, 0, 2)
    security_group_ids = [aws_security_group.msk_demo_sg.id]
  }

  client_authentication {
    sasl {
      iam {
        enabled = true
      }
    }
  }

  tags = {
    Name = "FintechDemoServerless"
  }
}


# 4. Fetch the bootstrap brokers (Required for Serverless outputs)
data "aws_msk_bootstrap_brokers" "kafka_endpoints" {
  cluster_arn = aws_msk_serverless_cluster.demo_msk.arn
}

# 5. Output for your demo connection string
output "bootstrap_brokers_sasl_iam" {
  description = "Connection string for your Kafka clients"
  value       = data.aws_msk_bootstrap_brokers.kafka_endpoints.bootstrap_brokers_sasl_iam
}

variable "aws_region" {
  type        = string
  description = "The target AWS deployment region"
  default     = "ap-south-1"
}

variable "valkey_engine_version" {
  type        = string
  description = "The version of the Valkey cache engine"
  default     = "7.2"
}

variable "valkey_node_type" {
  type        = string
  description = "The instance hardware class for practice cost-reduction"
  default     = "cache.t4g.small"
}

variable "target_subnets" {
  type        = list(string)
  description = "List of VPC Subnet IDs for the ElastiCache cluster placement"
  default     = ["subnet-0ad5ec3834e796e0d", "subnet-0085f77c1a13eb36c", "subnet-08e8146d5754843f7"]
}

variable "security_group_ids" {
  type        = list(string)
  description = "List of Security Group IDs authorized to connect to Valkey"
  default     = ["sg-0a7e1529fed5652fe"]
}

variable "aws_region" {
  type        = string
  description = "The target AWS Region for resource deployment."
  default     = "ap-south-1"
}

variable "environment" {
  type        = string
  description = "Deployment environment tag descriptor."
  default     = "SRE-Sandbox"
}

variable "bucket_prefix" {
  type        = string
  description = "Custom identifier string to ensure global S3 bucket naming uniqueness."
  default     = "wezvatech-sec-logs"
}


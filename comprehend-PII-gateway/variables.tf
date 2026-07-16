variable "aws_region" {
  type        = string
  description = "Target deployment AWS region space"
  default     = "ap-south-1"
}

variable "environment" {
  type        = string
  description = "Execution environment naming prefix context"
  default     = "production"
}

variable "raw_ingestion_bucket_id" {
  type        = string
  description = "The central S3 ingestion bucket name monitored for real-time dataset uploads"
  default     = "wezvatech-dvc-data-lake" # 🎯 CHANGE to match your central data lake bucket name
}

variable "lambda_timeout_seconds" {
  type        = number
  description = "Execution timeout window for processing heavy CSV token blocks (Max 900)"
  default     = 120
}


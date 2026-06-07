variable "bucket_name" {
  type        = string
  default     = "wezvatech-2026"
  description = "The globally unique name of the S3 bucket"
}

variable "enable_cloudfront" {
  type        = bool
  default     = false
  description = "Set to true to provision the CloudFront CDN architecture and lock down the bucket"
}
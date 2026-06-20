variable "project_id" {
  description = "The ID of the project in MongoDB Atlas"
  default     = "wezvatech"
}

variable "allowed_ips" {
  type        = list(string)
  description = "List of public IPs to allow access"
  default     = ["1.2.3.4", "5.6.7.8"] # Add your K8s public IP and local IP here
}

variable "atlas_public_key" {}

variable "atlas_private_key" {}


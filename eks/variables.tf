variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "cluster_name" {
  type    = string
  default = "WezvaTech-EKS-Demo"
}

variable "eksversion" {
  type    = string
  default = "1.33"
}

variable "caversion" {
  type    = string
  default = "v1.33.0"
}


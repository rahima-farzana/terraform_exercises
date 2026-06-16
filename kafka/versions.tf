terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    kafka = {
      source  = "Mongey/kafka"
      version = ">= 0.5.4"
    }
  }
}

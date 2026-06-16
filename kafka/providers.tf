provider "kafka" {

  # This splits the single MSK string into a clean list of addresses
  bootstrap_servers = split(",", data.aws_msk_bootstrap_brokers.kafka_endpoints.bootstrap_brokers_sasl_iam)


  tls_enabled     = true
  sasl_mechanism  = "aws-iam"
  sasl_aws_region = "ap-south-1" # Your region from the error log
}


provider "aws" {
    region     = "ap-south-1"
}

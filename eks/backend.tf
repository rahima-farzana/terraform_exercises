terraform {
  backend "s3" {
    bucket         = "wezvatech-2026-tfstate"
    key            = "product-name/envs/prod/eks.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    
    # Enable new native locking
    # not used in terraform 1.15.8,hence commenting out    use_lockfile   = true 

  }
}

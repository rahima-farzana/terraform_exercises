provider "aws" {
  region = "ap-south-1" # Mumbai
}

provider "mongodbatlas" {
  public_key  = var.atlas_public_key
  private_key = var.atlas_private_key
}

resource "mongodbatlas_advanced_cluster" "dev_cluster" {
  project_id   = var.project_id
  name         = "wezvatechdev"
  cluster_type = "REPLICASET" # change to SHARDED for production

  replication_specs {
    region_configs {
      priority      = 7
      region_name   = "AP_SOUTH_1" # Match your AWS region

      auto_scaling {
        compute_enabled = false # Disable for Dev to avoid surprise bills
        disk_gb_enabled = true
      }

      # For M0/M2/M5, provider_name MUST be "TENANT"
      provider_name         = "TENANT"
      backing_provider_name = "AWS"

      electable_specs {
        instance_size = "M0"
        node_count    = 3
      }
    }
  }

  # backup_enabled = false
}

resource "mongodbatlas_database_user" "dev_user" {
  username           = "admin"
  password           = "wezvatech" # Use a variable or secret manager in production
  project_id         = var.project_id
  auth_database_name = "admin"

  roles {
    role_name     = "readWrite"
    database_name = "dev_db" # The logical database the user can access
  }

  # Scoping ensures this user only works for this specific cluster
  scopes {
    name = mongodbatlas_advanced_cluster.dev_cluster.name
    type = "CLUSTER"
  }
}

output "standard_srv_connection_string" {
  description = "The standard SRV connection string for the cluster"
  value       = mongodbatlas_advanced_cluster.dev_cluster.connection_strings[0].standard_srv
}

output "full_connection_uri" {
  description = "The connection string including credentials (SENSITIVE)"
  value       = replace(
    mongodbatlas_advanced_cluster.dev_cluster.connection_strings[0].standard_srv,
    "mongodb+srv://",
    "mongodb+srv://${mongodbatlas_database_user.dev_user.username}:${mongodbatlas_database_user.dev_user.password}@"
  )
  sensitive = true
}

resource "mongodbatlas_project_ip_access_list" "local_access" {
  project_id = var.project_id
  ip_address = var.k8s_public_ip
  comment    = "Allow access from my local machine for kind cluster"
}

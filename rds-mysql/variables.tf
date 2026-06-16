variable "aws_region" {
  default = "ap-south-1"
}

variable "trigger_green_creation" {
  description = "Set to true to create the green deployment stack."
  type        = bool
  default     = false
}

variable "trigger_switchover" {
  description = "Set to true AFTER the green stack is created and tested, to perform the final cutover."
  type        = bool
  default     = false
}

variable "delete_source_db" {
  description = "Set to true, when blue db needs to be deleted after green stack is successfully cutover."
  type        = bool
  default     = false
}

variable "target_db_engine_version" {
  default     = "8.0.42" 
}

variable "target_instance_type" {
  description = "Choose the capacity of the instance to run MySQL"
  default     = "db.t3.micro"
}


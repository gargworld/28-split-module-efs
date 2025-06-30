variable "vpc_id" {
  description = "VPC ID where EFS resources will be deployed"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for EFS mount target"
  type        = string
}

variable "enable_create" {
  description = "Flag to enable or disable EFS creation"
  type        = bool
  default     = true
}

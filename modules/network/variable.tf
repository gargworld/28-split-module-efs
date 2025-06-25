variable "availability_zone" {
  description = "value for AZ"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR for the VPC"
  type        = string
}

variable "public_cidr" {
  description = "CIDR for the public subnet"
  type        = string
}

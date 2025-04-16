# modules/network/variables.tf - Placeholder 

variable "environment_name" {
  description = "A unique name for the deployment environment (e.g., \"prod\", \"staging\"). Used for tagging."
  type        = string
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
}

variable "availability_zones" {
  description = "A list of Availability Zones to deploy resources into."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "A list of CIDR blocks for the public subnets (one per AZ)."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "A list of CIDR blocks for the private subnets (one per AZ)."
  type        = list(string)
}

variable "db_subnet_cidrs" {
  description = "A list of CIDR blocks for the database subnets (one per AZ)."
  type        = list(string)
}

variable "tags" {
  description = "A map of tags to apply to all network resources."
  type        = map(string)
  default     = {}
} 
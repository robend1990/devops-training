variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster for which you want to create VPC"
}

variable "public_cidrs" {
  type        = list(string)
  description = "List of cidrs that will be used for public subnets (Min: 2). Each subnet is created in separate AZ so make sure that there is enough of them in selected region"

  validation {
    condition     = length(var.public_cidrs) >= 2
    error_message = "Length of public CIDR list must be 2 or greater and equal to length of private cidrs."
  }
}

variable "private_cidrs" {
  type        = list(string)
  description = "List of cidrs that will be used for private subnets (Min: 2). Each subnet is created in separate AZ so make sure that there is enough of them in selected region"

  validation {
    condition     = length(var.private_cidrs) >= 2
    error_message = "Length of private CIDR list must be 2 or greater and equal to length of public cidrs."
  }
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

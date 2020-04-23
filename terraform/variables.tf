variable "eks_cluster_name" {
  description = "Name of the EKS cluster for which you want to create resources"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}


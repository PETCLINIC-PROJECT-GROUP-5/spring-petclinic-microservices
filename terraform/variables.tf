variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "petclinic-cluster"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

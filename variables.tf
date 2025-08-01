variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "bluesunnywings-eks"
}

variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.32"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "bluesunnywings.com"
}

variable "node_groups" {
  description = "Map of EKS managed node group definitions to create"
  type        = any
  default = {
    main = {
      name           = "main"
      instance_types = ["t3.medium"]

      min_size     = 1
      max_size     = 4
      desired_size = 2

      disk_size     = 20
      ami_type      = "AL2_x86_64"
      capacity_type = "ON_DEMAND"

      k8s_labels = {
        Environment = "dev"
        NodeGroup   = "main"
      }
    }
  }
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default = {
    Terraform   = "true"
    Environment = "dev"
    Project     = "bluesunnywings"
  }
}
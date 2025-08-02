# =============================================================================
# TERRAFORM VARIABLES
# =============================================================================
# 이 파일은 Terraform 구성에서 사용되는 모든 변수를 정의합니다.
# terraform.tfvars 파일에서 이 변수들의 값을 설정할 수 있습니다.

# =============================================================================
# AWS CONFIGURATION
# =============================================================================

variable "aws_region" {
  description = "AWS 리전 - 모든 리소스가 생성될 AWS 리전"
  type        = string
  default     = "ap-northeast-2"
  
  validation {
    condition = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "AWS 리전은 올바른 형식이어야 합니다 (예: ap-northeast-2)."
  }
}

# =============================================================================
# EKS CLUSTER CONFIGURATION
# =============================================================================

variable "cluster_name" {
  description = "EKS 클러스터 이름 - 모든 관련 리소스의 이름 접두사로 사용됩니다"
  type        = string
  default     = "bluesunnywings-eks"
  
  validation {
    condition = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.cluster_name)) && length(var.cluster_name) <= 100
    error_message = "클러스터 이름은 문자로 시작하고, 문자, 숫자, 하이픈만 포함할 수 있으며, 100자를 초과할 수 없습니다."
  }
}

variable "cluster_version" {
  description = "EKS 클러스터 Kubernetes 버전 - 지원되는 Kubernetes 버전을 사용해야 합니다"
  type        = string
  default     = "1.32"
  
  validation {
    condition = can(regex("^1\\.[0-9]+$", var.cluster_version))
    error_message = "클러스터 버전은 올바른 Kubernetes 버전 형식이어야 합니다 (예: 1.32)."
  }
}

# =============================================================================
# NETWORK CONFIGURATION
# =============================================================================

variable "vpc_cidr" {
  description = "VPC CIDR 블록 - EKS 클러스터와 워커 노드가 사용할 네트워크 주소 범위"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR은 올바른 CIDR 형식이어야 합니다 (예: 10.0.0.0/16)."
  }
}

# =============================================================================
# DOMAIN AND DNS CONFIGURATION
# =============================================================================

variable "domain_name" {
  description = "도메인 이름 - Route53 호스팅 존과 ACM 인증서에 사용되는 도메인 (기존 리소스 필요)"
  type        = string
  default     = "bluesunnywings.com"
  
  validation {
    condition = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]*\\.[a-zA-Z]{2,}$", var.domain_name))
    error_message = "도메인 이름은 올바른 형식이어야 합니다 (예: example.com)."
  }
}

# =============================================================================
# EKS NODE GROUPS CONFIGURATION
# =============================================================================

variable "node_groups" {
  description = "EKS 관리형 노드 그룹 정의 - 워커 노드의 구성을 정의합니다"
  type        = any
  default = {
    main = {
      name           = "main"                    # 노드 그룹 이름
      instance_types = ["t3.medium"]            # EC2 인스턴스 타입 목록

      # Auto Scaling 설정
      min_size     = 1                          # 최소 노드 수
      max_size     = 4                          # 최대 노드 수
      desired_size = 2                          # 원하는 노드 수

      # 스토리지 및 인스턴스 설정
      disk_size     = 20                        # EBS 볼륨 크기 (GB)
      ami_type      = "AL2_x86_64"             # Amazon Linux 2 AMI 타입
      capacity_type = "ON_DEMAND"              # 인스턴스 구매 옵션 (ON_DEMAND 또는 SPOT)

      # Kubernetes 레이블
      k8s_labels = {
        Environment = "dev"
        NodeGroup   = "main"
      }
    }
  }
  
  validation {
    condition = alltrue([
      for ng in var.node_groups : ng.min_size <= ng.desired_size && ng.desired_size <= ng.max_size
    ])
    error_message = "각 노드 그룹에서 min_size <= desired_size <= max_size 조건을 만족해야 합니다."
  }
}

# =============================================================================
# RESOURCE TAGGING
# =============================================================================

variable "tags" {
  description = "모든 리소스에 적용될 공통 태그 - 리소스 관리 및 비용 추적에 사용됩니다"
  type        = map(string)
  default = {
    Terraform   = "true"                       # Terraform으로 관리되는 리소스임을 표시
    Environment = "dev"                        # 환경 구분 (dev, staging, prod 등)
    Project     = "bluesunnywings"            # 프로젝트 이름
  }
  
  validation {
    condition = contains(keys(var.tags), "Environment") && contains(keys(var.tags), "Project")
    error_message = "태그에는 최소한 Environment와 Project 키가 포함되어야 합니다."
  }
}
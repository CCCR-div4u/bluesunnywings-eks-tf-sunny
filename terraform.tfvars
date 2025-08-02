# =============================================================================
# TERRAFORM VARIABLES VALUES
# =============================================================================
# 이 파일은 variables.tf에서 정의된 변수들의 실제 값을 설정합니다.
# 환경에 맞게 값을 수정하여 사용하세요.

# =============================================================================
# AWS CONFIGURATION
# =============================================================================

# AWS 리전 설정
aws_region = "ap-northeast-2"

# =============================================================================
# EKS CLUSTER CONFIGURATION
# =============================================================================

# EKS 클러스터 이름 (모든 리소스 이름의 접두사로 사용됨)
cluster_name = "bluesunnywings-eks"

# Kubernetes 버전 (AWS에서 지원하는 버전 확인 필요)
cluster_version = "1.32"

# =============================================================================
# NETWORK CONFIGURATION
# =============================================================================

# VPC CIDR 블록 (필요시 변경 가능)
vpc_cidr = "10.0.0.0/16"

# =============================================================================
# DOMAIN AND DNS CONFIGURATION
# =============================================================================

# 도메인 이름 (기존 Route53 호스팅 존과 ACM 인증서가 필요)
# 주의: 이 도메인에 대한 호스팅 존과 인증서가 미리 생성되어 있어야 합니다.
domain_name = "bluesunnywings.com"

# =============================================================================
# EKS NODE GROUPS CONFIGURATION
# =============================================================================

# 노드 그룹 설정 (필요에 따라 수정 가능)
node_groups = {
  main = {
    name           = "main"
    instance_types = ["t3.medium"]  # 비용 최적화를 위해 t3.medium 사용

    # Auto Scaling 설정
    min_size     = 1  # 최소 노드 수
    max_size     = 4  # 최대 노드 수 (트래픽 증가 시 자동 확장)
    desired_size = 2  # 기본 노드 수

    # 스토리지 및 인스턴스 설정
    disk_size     = 20           # EBS 볼륨 크기 (GB)
    ami_type      = "AL2_x86_64" # Amazon Linux 2 AMI
    capacity_type = "ON_DEMAND"  # 안정성을 위해 ON_DEMAND 사용 (SPOT도 가능)

    # Kubernetes 레이블 (Pod 스케줄링 시 사용 가능)
    k8s_labels = {
      Environment = "dev"
      NodeGroup   = "main"
    }
  }

  # 추가 노드 그룹이 필요한 경우 아래와 같이 정의 가능
  # spot = {
  #   name           = "spot"
  #   instance_types = ["t3.medium", "t3.large"]
  #   
  #   min_size     = 0
  #   max_size     = 10
  #   desired_size = 2
  #   
  #   disk_size     = 20
  #   ami_type      = "AL2_x86_64"
  #   capacity_type = "SPOT"  # 비용 절약을 위한 SPOT 인스턴스
  #   
  #   k8s_labels = {
  #     Environment = "dev"
  #     NodeGroup   = "spot"
  #     InstanceType = "spot"
  #   }
  # }
}

# =============================================================================
# RESOURCE TAGGING
# =============================================================================

# 모든 리소스에 적용될 공통 태그
tags = {
  Terraform   = "true"           # Terraform으로 관리되는 리소스
  Environment = "dev"            # 환경 구분 (dev, staging, prod)
  Project     = "bluesunnywings" # 프로젝트 이름
  Owner       = "DevOps Team"    # 리소스 소유자
  CostCenter  = "Engineering"    # 비용 센터 (비용 추적용)
}

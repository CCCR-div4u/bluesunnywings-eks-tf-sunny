# =============================================================================
# TERRAFORM CONFIGURATION
# =============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# =============================================================================
# PROVIDERS
# =============================================================================

# AWS Provider - 기본 AWS 리소스 관리
provider "aws" {
  region = var.aws_region
}

# =============================================================================
# DATA SOURCES
# =============================================================================

# 사용 가능한 가용 영역 조회 (opt-in 불필요한 영역만)
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# 현재 AWS 계정 정보 조회
data "aws_caller_identity" "current" {}

# 현재 AWS 리전 정보 조회
data "aws_region" "current" {}

# =============================================================================
# VPC AND NETWORKING
# =============================================================================

# VPC 생성 - EKS 클러스터와 워커 노드를 위한 네트워크 환경
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true  # EKS 클러스터 통신을 위해 필수
  enable_dns_support   = true  # DNS 해석 활성화

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-vpc"
    # EKS 클러스터가 이 VPC를 공유 리소스로 인식하도록 태그 설정
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

# 인터넷 게이트웨이 - 퍼블릭 서브넷의 인터넷 연결 제공
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-igw"
  })
}

# 퍼블릭 서브넷 - ALB, NAT Gateway 배치용 (2개 AZ)
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)  # 10.0.0.0/24, 10.0.1.0/24
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true  # 퍼블릭 IP 자동 할당

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-public-${count.index + 1}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    # ALB가 이 서브넷을 사용할 수 있도록 태그 설정
    "kubernetes.io/role/elb" = "1"
  })
}

# 프라이빗 서브넷 - EKS 워커 노드 배치용 (2개 AZ)
resource "aws_subnet" "private" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)  # 10.0.10.0/24, 10.0.11.0/24
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-private-${count.index + 1}"
    # EKS가 이 서브넷을 소유하고 있음을 표시
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    # 내부 로드밸런서(NLB)가 이 서브넷을 사용할 수 있도록 태그 설정
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# NAT Gateway용 Elastic IP (각 AZ별로 생성)
resource "aws_eip" "nat" {
  count  = 2
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-nat-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway - 프라이빗 서브넷의 아웃바운드 인터넷 연결 제공 (고가용성을 위해 각 AZ별 배치)
resource "aws_nat_gateway" "main" {
  count = 2

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-nat-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# 퍼블릭 라우팅 테이블 - 인터넷 게이트웨이로 트래픽 라우팅
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-public"
  })
}

# 프라이빗 라우팅 테이블 - NAT Gateway로 아웃바운드 트래픽 라우팅 (각 AZ별)
resource "aws_route_table" "private" {
  count = 2

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-private-${count.index + 1}"
  })
}

# 퍼블릭 서브넷과 퍼블릭 라우팅 테이블 연결
resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# 프라이빗 서브넷과 프라이빗 라우팅 테이블 연결
resource "aws_route_table_association" "private" {
  count = 2

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# =============================================================================
# IAM ROLES FOR EKS
# =============================================================================

# EKS 클러스터 서비스 역할 - EKS 컨트롤 플레인이 AWS 리소스를 관리하기 위한 역할
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  # EKS 서비스가 이 역할을 assume할 수 있도록 신뢰 정책 설정
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# EKS 클러스터 정책 연결 - 클러스터 관리에 필요한 권한 부여
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# EKS 노드 그룹 역할 - 워커 노드가 AWS 리소스에 접근하기 위한 역할
resource "aws_iam_role" "node_group" {
  name = "${var.cluster_name}-node-group-role"

  # EC2 인스턴스가 이 역할을 assume할 수 있도록 신뢰 정책 설정
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# 워커 노드 정책들 연결
resource "aws_iam_role_policy_attachment" "node_group_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_group_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_group_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group.name
}

# =============================================================================
# EKS CLUSTER
# =============================================================================

# EKS 클러스터 생성 - Kubernetes 컨트롤 플레인
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  vpc_config {
    # 클러스터 ENI가 배치될 서브넷 (프라이빗 + 퍼블릭)
    subnet_ids              = concat(aws_subnet.private[*].id, aws_subnet.public[*].id)
    endpoint_private_access = true   # VPC 내부에서 API 서버 접근 허용
    endpoint_public_access  = true   # 인터넷에서 API 서버 접근 허용
    public_access_cidrs     = ["0.0.0.0/0"]  # 모든 IP에서 접근 허용 (보안상 필요시 제한 가능)
  }

  # 클러스터 로깅 활성화 - CloudWatch Logs로 전송
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
  ]

  tags = var.tags
}

# =============================================================================
# OIDC IDENTITY PROVIDER
# =============================================================================

# EKS 클러스터의 OIDC 인증서 정보 조회
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# OIDC Identity Provider 생성 - IRSA(IAM Role for Service Account) 기능을 위해 필요
resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = var.tags
}

# =============================================================================
# EKS NODE GROUPS
# =============================================================================

# EKS 관리형 노드 그룹 - 워커 노드 생성 및 관리
resource "aws_eks_node_group" "main" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = each.value.name
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = aws_subnet.private[*].id  # 보안을 위해 프라이빗 서브넷에만 배치

  # 인스턴스 설정
  capacity_type  = each.value.capacity_type   # ON_DEMAND 또는 SPOT
  instance_types = each.value.instance_types  # EC2 인스턴스 타입
  ami_type       = each.value.ami_type        # Amazon Linux 2 AMI 타입
  disk_size      = each.value.disk_size       # EBS 볼륨 크기 (GB)

  # Auto Scaling 설정
  scaling_config {
    desired_size = each.value.desired_size  # 원하는 노드 수
    max_size     = each.value.max_size      # 최대 노드 수
    min_size     = each.value.min_size      # 최소 노드 수
  }

  # Kubernetes 레이블 설정
  labels = each.value.k8s_labels

  # Cluster Autoscaler가 이 노드 그룹을 관리할 수 있도록 태그 설정
  tags = merge(var.tags, {
    "k8s.io/cluster-autoscaler/enabled" = "true"
    "k8s.io/cluster-autoscaler/${aws_eks_cluster.main.name}" = "owned"
  })

  depends_on = [
    aws_iam_role_policy_attachment.node_group_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_group_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_group_AmazonEC2ContainerRegistryReadOnly,
  ]
}

# =============================================================================
# ROUTE53 AND ACM (EXISTING RESOURCES)
# =============================================================================

# 기존 Route53 호스팅 존 조회 - 도메인 DNS 관리용
# 주의: 이 리소스는 기존에 생성되어 있어야 하며, Terraform destroy 시 삭제되지 않음
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# 기존 ACM 인증서 조회 - HTTPS 통신용 SSL/TLS 인증서
# 주의: 이 리소스는 기존에 생성되어 있어야 하며, ISSUED 상태여야 함
data "aws_acm_certificate" "main" {
  domain   = var.domain_name
  statuses = ["ISSUED"]
}

# =============================================================================
# KUBERNETES AND HELM PROVIDERS CONFIGURATION
# =============================================================================

# EKS 클러스터 인증 토큰 조회 - Kubernetes/Helm Provider 인증용
data "aws_eks_cluster_auth" "main" {
  name = aws_eks_cluster.main.name
}

# Kubernetes Provider - EKS 클러스터에 Kubernetes 리소스 배포용
provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
}

# Helm Provider - EKS 클러스터에 Helm 차트 배포용
provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}

# =============================================================================
# IRSA ROLES FOR EKS ADD-ONS
# =============================================================================

# EBS CSI Driver용 IRSA 역할 - EBS 볼륨 관리 권한
module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20"

  role_name             = "${var.cluster_name}-ebs-csi-driver"
  attach_ebs_csi_policy = true  # EBS CSI Driver에 필요한 정책 자동 연결

  oidc_providers = {
    ex = {
      provider_arn               = aws_iam_openid_connect_provider.cluster.arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = var.tags
}

# =============================================================================
# EKS ADD-ONS
# =============================================================================

# EBS CSI Driver 애드온 - EBS 볼륨을 Kubernetes PV로 사용
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
  
  depends_on = [aws_eks_node_group.main, module.ebs_csi_irsa_role]
}

# VPC CNI 애드온 - Pod 네트워킹 관리
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"
  
  depends_on = [aws_eks_node_group.main]
}

# CoreDNS 애드온 - 클러스터 내부 DNS 서비스
resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"
  
  depends_on = [aws_eks_node_group.main]
}

# Kube Proxy 애드온 - 네트워크 프록시 및 로드밸런싱
resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"
  
  depends_on = [aws_eks_node_group.main]
}

# =============================================================================
# AWS LOAD BALANCER CONTROLLER
# =============================================================================

# AWS Load Balancer Controller용 IRSA 역할 - ALB/NLB 관리 권한
module "aws_load_balancer_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20"

  role_name = "${var.cluster_name}-aws-load-balancer-controller"

  # AWS Load Balancer Controller에 필요한 정책 자동 연결
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = aws_iam_openid_connect_provider.cluster.arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = var.tags
}

# =============================================================================
# EXTERNAL DNS
# =============================================================================

# External DNS용 IRSA 역할 - Route53 DNS 레코드 관리 권한
module "external_dns_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20"

  role_name                     = "${var.cluster_name}-external-dns"
  attach_external_dns_policy    = true  # External DNS에 필요한 정책 자동 연결
  external_dns_hosted_zone_arns = ["arn:aws:route53:::hostedzone/${data.aws_route53_zone.main.zone_id}"]

  oidc_providers = {
    ex = {
      provider_arn               = aws_iam_openid_connect_provider.cluster.arn
      namespace_service_accounts = ["kube-system:external-dns"]
    }
  }

  tags = var.tags
}

# AWS Load Balancer Controller Helm 차트 배포 - Kubernetes Ingress를 ALB/NLB로 변환
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.6.2"

  # 클러스터 이름 설정
  set {
    name  = "clusterName"
    value = aws_eks_cluster.main.name
  }

  # ServiceAccount 생성 및 설정
  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  # IRSA 역할 ARN 설정
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.aws_load_balancer_controller_irsa_role.iam_role_arn
  }

  # AWS 리전 설정
  set {
    name  = "region"
    value = data.aws_region.current.name
  }

  # VPC ID 설정
  set {
    name  = "vpcId"
    value = aws_vpc.main.id
  }

  depends_on = [
    aws_eks_node_group.main,
    module.aws_load_balancer_controller_irsa_role
  ]
}

# External DNS Helm 차트 배포 - Kubernetes Service/Ingress를 Route53 DNS 레코드로 자동 등록
resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "kube-system"
  version    = "1.13.1"

  # ServiceAccount 생성 및 설정
  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "external-dns"
  }

  # IRSA 역할 ARN 설정
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.external_dns_irsa_role.iam_role_arn
  }

  # AWS Provider 설정
  set {
    name  = "provider"
    value = "aws"
  }

  # AWS 리전 설정
  set {
    name  = "aws.region"
    value = data.aws_region.current.name
  }

  # 퍼블릭 호스팅 존 사용
  set {
    name  = "aws.zoneType"
    value = "public"
  }

  # TXT 레코드 소유자 ID 설정 (충돌 방지)
  set {
    name  = "txtOwnerId"
    value = data.aws_route53_zone.main.zone_id
  }

  # 관리할 도메인 필터 설정
  set {
    name  = "domainFilters[0]"
    value = var.domain_name
  }

  # DNS 레코드 정책 (기존 레코드 업데이트만 허용)
  set {
    name  = "policy"
    value = "upsert-only"
  }

  depends_on = [
    aws_eks_node_group.main,
    module.external_dns_irsa_role
  ]
}

# =============================================================================
# CLUSTER AUTOSCALER
# =============================================================================

# Cluster Autoscaler용 IRSA 역할 - EC2 Auto Scaling 그룹 관리 권한
module "cluster_autoscaler_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20"

  role_name                        = "${var.cluster_name}-cluster-autoscaler"
  attach_cluster_autoscaler_policy = true  # Cluster Autoscaler에 필요한 정책 자동 연결
  cluster_autoscaler_cluster_names = [aws_eks_cluster.main.name]

  oidc_providers = {
    ex = {
      provider_arn               = aws_iam_openid_connect_provider.cluster.arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }

  tags = var.tags
}

# Cluster Autoscaler Helm 차트 배포 - 노드 자동 스케일링
resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = "9.29.0"

  # 클러스터 자동 발견 설정
  set {
    name  = "autoDiscovery.clusterName"
    value = aws_eks_cluster.main.name
  }

  # AWS 리전 설정
  set {
    name  = "awsRegion"
    value = data.aws_region.current.name
  }

  # ServiceAccount 생성 및 설정
  set {
    name  = "rbac.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }

  # IRSA 역할 ARN 설정
  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.cluster_autoscaler_irsa_role.iam_role_arn
  }

  # 스케일 다운 지연 시간 설정 (노드 추가 후)
  set {
    name  = "extraArgs.scale-down-delay-after-add"
    value = "10m"
  }

  # 불필요한 노드 제거 대기 시간
  set {
    name  = "extraArgs.scale-down-unneeded-time"
    value = "10m"
  }

  depends_on = [
    aws_eks_node_group.main,
    module.cluster_autoscaler_irsa_role
  ]
}

# =============================================================================
# STORAGE CLASSES
# =============================================================================

# GP3 StorageClass 생성 - 기본 스토리지 클래스로 설정
resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy        = "Delete"                    # PVC 삭제 시 PV도 삭제
  volume_binding_mode   = "WaitForFirstConsumer"     # Pod 스케줄링 후 볼륨 바인딩
  allow_volume_expansion = true                       # 볼륨 확장 허용

  parameters = {
    type      = "gp3"    # GP3 볼륨 타입 사용
    encrypted = "true"   # 암호화 활성화
  }

  depends_on = [aws_eks_addon.ebs_csi]
}

# 기본 GP2 StorageClass 비활성화 - GP3를 기본값으로 사용하기 위해
resource "kubernetes_annotations" "gp2_default" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  metadata {
    name = "gp2"
  }
  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }

  depends_on = [kubernetes_storage_class.gp3]
}
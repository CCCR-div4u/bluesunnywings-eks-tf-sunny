# =============================================================================
# TERRAFORM OUTPUTS
# =============================================================================
# 이 파일은 Terraform 배포 완료 후 출력되는 중요한 정보들을 정의합니다.
# 이 정보들은 kubectl 설정, 애플리케이션 배포, 모니터링 등에 사용됩니다.

# =============================================================================
# EKS CLUSTER INFORMATION
# =============================================================================

output "cluster_id" {
  description = "EKS 클러스터 ID - 클러스터의 고유 식별자"
  value       = aws_eks_cluster.main.id
}

output "cluster_arn" {
  description = "EKS 클러스터 ARN - AWS 리소스 식별을 위한 Amazon Resource Name"
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "EKS 컨트롤 플레인 엔드포인트 - kubectl 명령어 실행을 위한 API 서버 주소"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_security_group_id" {
  description = "EKS 클러스터 컨트롤 플레인 보안 그룹 ID - 네트워크 접근 제어용"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_primary_security_group_id" {
  description = "EKS가 자동 생성한 클러스터 기본 보안 그룹 ID - 클러스터-노드 간 통신용"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_certificate_authority_data" {
  description = "EKS 클러스터 인증서 데이터 - kubectl 클라이언트 인증을 위한 CA 인증서 (Base64 인코딩)"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true  # 민감한 정보로 표시하여 로그에 출력되지 않도록 함
}

# =============================================================================
# IAM ROLES INFORMATION
# =============================================================================

output "cluster_iam_role_name" {
  description = "EKS 클러스터 IAM 역할 이름 - 클러스터 서비스 역할"
  value       = aws_iam_role.cluster.name
}

output "cluster_iam_role_arn" {
  description = "EKS 클러스터 IAM 역할 ARN - 클러스터 권한 관리용"
  value       = aws_iam_role.cluster.arn
}

# =============================================================================
# OIDC AND IRSA INFORMATION
# =============================================================================

output "oidc_issuer_url" {
  description = "EKS 클러스터 OIDC 발급자 URL - IRSA(IAM Role for Service Account) 설정용"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "OIDC Identity Provider ARN - IRSA 역할 생성 시 필요한 ARN"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

# =============================================================================
# NODE GROUPS INFORMATION
# =============================================================================

output "node_groups" {
  description = "EKS 노드 그룹 정보 - 워커 노드 그룹의 상세 정보"
  value       = aws_eks_node_group.main
}

# =============================================================================
# NETWORK INFORMATION
# =============================================================================

output "vpc_id" {
  description = "VPC ID - 클러스터와 노드가 배포된 VPC의 식별자"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR 블록 - VPC의 IP 주소 범위"
  value       = aws_vpc.main.cidr_block
}

output "private_subnets" {
  description = "프라이빗 서브넷 ID 목록 - 워커 노드가 배치된 서브넷들"
  value       = aws_subnet.private[*].id
}

output "public_subnets" {
  description = "퍼블릭 서브넷 ID 목록 - ALB와 NAT Gateway가 배치된 서브넷들"
  value       = aws_subnet.public[*].id
}

# =============================================================================
# DNS AND CERTIFICATE INFORMATION
# =============================================================================

output "hosted_zone_id" {
  description = "Route53 호스팅 존 ID - DNS 레코드 관리를 위한 호스팅 존 식별자"
  value       = data.aws_route53_zone.main.zone_id
}

output "hosted_zone_name_servers" {
  description = "Route53 호스팅 존 네임서버 목록 - 도메인 DNS 설정용"
  value       = data.aws_route53_zone.main.name_servers
}

output "certificate_arn" {
  description = "ACM 인증서 ARN - HTTPS 통신을 위한 SSL/TLS 인증서"
  value       = data.aws_acm_certificate.main.arn
}

# =============================================================================
# IRSA ROLES FOR ADD-ONS
# =============================================================================

output "aws_load_balancer_controller_role_arn" {
  description = "AWS Load Balancer Controller IAM 역할 ARN - ALB/NLB 관리 권한"
  value       = module.aws_load_balancer_controller_irsa_role.iam_role_arn
}

output "external_dns_role_arn" {
  description = "External DNS IAM 역할 ARN - Route53 DNS 레코드 관리 권한"
  value       = module.external_dns_irsa_role.iam_role_arn
}

output "ebs_csi_role_arn" {
  description = "EBS CSI Driver IAM 역할 ARN - EBS 볼륨 관리 권한"
  value       = module.ebs_csi_irsa_role.iam_role_arn
}

output "cluster_autoscaler_role_arn" {
  description = "Cluster Autoscaler IAM 역할 ARN - 노드 자동 스케일링 권한"
  value       = module.cluster_autoscaler_irsa_role.iam_role_arn
}

# =============================================================================
# KUBECTL CONFIGURATION COMMAND
# =============================================================================

output "kubectl_config_command" {
  description = "kubectl 설정 명령어 - 클러스터 접근을 위한 kubeconfig 업데이트 명령어"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}
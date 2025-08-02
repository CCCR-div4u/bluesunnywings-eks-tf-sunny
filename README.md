# 🚀 EKS Terraform One-Action Deployment

[![Terraform](https://img.shields.io/badge/Terraform-1.0+-623CE4?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-EKS-FF9900?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/eks/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.32-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

이 프로젝트는 **AWS EKS 클러스터와 모든 필수 애드온을 한번에 배포**하는 완전한 Terraform 구성입니다. 
프로덕션 환경에서 바로 사용할 수 있는 고가용성 EKS 클러스터를 15-20분 만에 구축할 수 있습니다.

## 📋 목차

- [🏗️ 아키텍처 개요](#️-아키텍처-개요)
- [✨ 주요 특징](#-주요-특징)
- [🔧 포함된 구성 요소](#-포함된-구성-요소)
- [📋 사전 요구사항](#-사전-요구사항)
- [🚀 빠른 시작](#-빠른-시작)
- [⚙️ 상세 설정 가이드](#️-상세-설정-가이드)
- [📊 배포 후 확인](#-배포-후-확인)
- [🔍 트러블슈팅](#-트러블슈팅)
- [🧹 리소스 정리](#-리소스-정리)
- [💰 비용 최적화](#-비용-최적화)
- [🔒 보안 고려사항](#-보안-고려사항)
- [📚 추가 리소스](#-추가-리소스)

## ✨ 주요 특징

- 🎯 **원클릭 배포**: 단일 `terraform apply` 명령으로 전체 스택 배포
- 🏗️ **프로덕션 준비**: 고가용성, 보안, 모니터링이 고려된 아키텍처
- 🔄 **자동 스케일링**: Cluster Autoscaler와 HPA 지원
- 🌐 **완전한 네트워킹**: VPC, 서브넷, NAT Gateway, 로드밸런서 자동 구성
- 🔐 **보안 강화**: IRSA, 네트워크 분리, 암호화 스토리지
- 📈 **모니터링 준비**: CloudWatch 로깅, 메트릭 수집 기본 설정
- 🔧 **유연한 설정**: 변수를 통한 쉬운 커스터마이징

## 🏗️ 아키텍처 개요

### 전체 아키텍처
```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                    AWS Cloud                                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │                              VPC (10.0.0.0/16)                             │ │
│  │                                                                             │ │
│  │  ┌─────────────────────┐                    ┌─────────────────────┐        │ │
│  │  │    Public Subnet    │                    │    Public Subnet    │        │ │
│  │  │   (10.0.0.0/24)     │                    │   (10.0.1.0/24)     │        │ │
│  │  │        AZ-a         │                    │        AZ-c         │        │ │
│  │  │                     │                    │                     │        │ │
│  │  │  ┌─────────────────┐│                    │┌─────────────────┐  │        │ │
│  │  │  │   NAT Gateway   ││                    ││   NAT Gateway   │  │        │ │
│  │  │  └─────────────────┘│                    │└─────────────────┘  │        │ │
│  │  │  ┌─────────────────┐│                    │┌─────────────────┐  │        │ │
│  │  │  │       ALB       ││                    ││       ALB       │  │        │ │
│  │  │  └─────────────────┘│                    │└─────────────────┘  │        │ │
│  │  └─────────────────────┘                    └─────────────────────┘        │ │
│  │                                                                             │ │
│  │  ┌─────────────────────┐                    ┌─────────────────────┐        │ │
│  │  │   Private Subnet    │                    │   Private Subnet    │        │ │
│  │  │   (10.0.10.0/24)    │                    │   (10.0.11.0/24)    │        │ │
│  │  │        AZ-a         │                    │        AZ-c         │        │ │
│  │  │                     │                    │                     │        │ │
│  │  │  ┌─────────────────┐│                    │┌─────────────────┐  │        │ │
│  │  │  │  Worker Nodes   ││                    ││  Worker Nodes   │  │        │ │
│  │  │  │   (t3.medium)   ││                    ││   (t3.medium)   │  │        │ │
│  │  │  └─────────────────┘│                    │└─────────────────┘  │        │ │
│  │  └─────────────────────┘                    └─────────────────────┘        │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                   │
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │                            EKS Control Plane                               │ │
│  │                          (Managed by AWS)                                  │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                              External Services                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│  Route53 (bluesunnywings.com)  │  ACM Certificate (*.bluesunnywings.com)       │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 네트워크 구성
- **VPC**: 10.0.0.0/16 CIDR 블록으로 격리된 네트워크 환경
- **가용 영역**: 2개 AZ에 걸친 고가용성 구성 (ap-northeast-2a, ap-northeast-2c)
- **퍼블릭 서브넷**: 10.0.0.0/24, 10.0.1.0/24 (ALB, NAT Gateway 배치)
- **프라이빗 서브넷**: 10.0.10.0/24, 10.0.11.0/24 (EKS 워커 노드 배치)
- **NAT Gateway**: 각 AZ별 배치로 고가용성 보장 및 아웃바운드 인터넷 연결

### EKS 클러스터 구성
- **Kubernetes 버전**: 1.32 (최신 안정 버전)
- **엔드포인트**: 프라이빗 + 퍼블릭 접근 허용 (보안 그룹으로 제어)
- **로깅**: API, Audit, Authenticator, ControllerManager, Scheduler 활성화
- **OIDC Provider**: IRSA(IAM Role for Service Account) 지원으로 세밀한 권한 제어

### 워커 노드 구성
- **인스턴스 타입**: t3.medium (2 vCPU, 4GB RAM) - 비용 효율적
- **Auto Scaling**: 최소 1대, 원하는 2대, 최대 4대 (트래픽에 따른 자동 확장)
- **스토리지**: GP3 20GB (암호화 활성화, 성능 최적화)
- **배치**: 프라이빗 서브넷만 사용하여 보안 강화

## 🔧 포함된 구성 요소

### 1. 기본 인프라
- ✅ VPC with Public/Private 서브넷 (2 AZ)
- ✅ Internet Gateway & NAT Gateway
- ✅ 적절한 라우팅 테이블 구성
- ✅ 보안 그룹 자동 구성

### 2. EKS 클러스터
- ✅ EKS 클러스터 (Kubernetes 1.32)
- ✅ 관리형 노드 그룹
- ✅ 클러스터 로깅 활성화
- ✅ OIDC Identity Provider

### 3. EKS 애드온
- ✅ **AWS EBS CSI Driver**: GP3 스토리지 지원
- ✅ **VPC CNI**: 네트워크 플러그인
- ✅ **CoreDNS**: DNS 서비스
- ✅ **Kube Proxy**: 네트워크 프록시
- ✅ **AWS Load Balancer Controller**: ALB/NLB 지원
- ✅ **External DNS**: Route53 자동 DNS 관리
- ✅ **Cluster Autoscaler**: 노드 자동 스케일링

### 4. 도메인 & 인증서
- ✅ **Route53 호스팅 존**: bluesunnywings.com (기존 리소스 사용)
- ✅ **ACM 인증서**: *.bluesunnywings.com (기존 리소스 사용)
- ✅ **리소스 보존**: destroy 시 호스팅 존과 인증서 삭제 안됨

### 5. IAM 역할 (IRSA)
- ✅ **EKS 클러스터 서비스 역할**
- ✅ **노드 그룹 인스턴스 역할**
- ✅ **AWS Load Balancer Controller 역할**
- ✅ **External DNS 역할** (Route53 권한)
- ✅ **EBS CSI Driver 역할**
- ✅ **Cluster Autoscaler 역할** (EC2 Auto Scaling 권한)

### 6. 스토리지
- ✅ **GP3 StorageClass** (기본값으로 설정)
- ✅ **볼륨 확장 지원**
- ✅ **암호화 활성화**

## 📋 사전 요구사항

### 필수 도구 설치

#### 1. AWS CLI 설치 및 구성
```bash
# AWS CLI 설치 (macOS)
brew install awscli

# AWS CLI 설치 (Linux)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# AWS 자격 증명 구성
aws configure
```

#### 2. Terraform 설치
```bash
# Terraform 설치 (macOS)
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Terraform 설치 (Linux)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# 설치 확인
terraform version
```

#### 3. kubectl 설치
```bash
# kubectl 설치 (macOS)
brew install kubectl

# kubectl 설치 (Linux)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# 설치 확인
kubectl version --client
```

#### 4. Helm 설치
```bash
# Helm 설치 (macOS)
brew install helm

# Helm 설치 (Linux)
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update && sudo apt-get install helm

# 설치 확인
helm version
```

### 필수 AWS 리소스

⚠️ **중요**: 배포 전에 다음 리소스들이 미리 생성되어 있어야 합니다:

#### 1. Route53 호스팅 존
```bash
# 호스팅 존 존재 확인
aws route53 list-hosted-zones --query "HostedZones[?Name=='bluesunnywings.com.']"
```

#### 2. ACM 인증서
```bash
# 인증서 존재 및 상태 확인
aws acm list-certificates --region ap-northeast-2 --query "CertificateSummaryList[?DomainName=='bluesunnywings.com']"
```

### AWS IAM 권한

배포를 위해 다음 AWS 서비스에 대한 권한이 필요합니다:
- **EC2**: VPC, 서브넷, 보안 그룹, NAT Gateway 관리
- **EKS**: 클러스터 및 노드 그룹 관리
- **IAM**: 역할 및 정책 관리
- **Route53**: DNS 레코드 관리 (기존 호스팅 존 사용)
- **ACM**: 인증서 조회 (기존 인증서 사용)
- **CloudWatch**: 로깅 설정

### 환경 변수 설정 (선택사항)
```bash
# AWS 프로파일 설정 (여러 계정 사용 시)
export AWS_PROFILE=your-profile-name

# AWS 리전 설정
export AWS_DEFAULT_REGION=ap-northeast-2
```

## 🚀 빠른 시작

### 1. 리포지토리 클론 및 디렉토리 이동
```bash
git clone <repository-url>
cd bluesunnywings-eks-tf-sunny
```

### 2. Terraform 초기화
```bash
terraform init
```

### 3. 변수 설정 (선택사항)
`terraform.tfvars` 파일을 수정하여 원하는 설정으로 변경:
```hcl
cluster_name = "your-cluster-name"
domain_name = "your-domain.com"
aws_region = "ap-northeast-2"
```

### 4. 배포 계획 확인
```bash
terraform plan
```

### 5. 배포 실행
```bash
# 일반 실행
terraform apply

# 백그라운드 실행 (권장)
nohup terraform apply -auto-approve > ./log/"$(date +'%y%m%d_%H%M').tf.log" 2>&1 &
```

**백그라운드 실행 시:**
- 터미널 종료해도 배포 계속 진행
- 로그는 `./log/` 디렉터리에 자동 저장
- `tail -f ./log/최신로그파일.log`로 진행 상황 확인

### 6. kubectl 설정
```bash
aws eks update-kubeconfig --region ap-northeast-2 --name bluesunnywings-eks
```

## ⚙️ 상세 설정 가이드

### 변수 커스터마이징

#### 클러스터 설정
```hcl
# terraform.tfvars
cluster_name = "my-eks-cluster"
cluster_version = "1.32"
aws_region = "ap-northeast-2"
```

#### 네트워크 설정
```hcl
vpc_cidr = "10.0.0.0/16"  # VPC CIDR 블록
```

#### 노드 그룹 설정
```hcl
node_groups = {
  main = {
    name           = "main"
    instance_types = ["t3.medium"]
    
    min_size     = 1
    max_size     = 4
    desired_size = 2
    
    disk_size     = 20
    ami_type      = "AL2_x86_64"
    capacity_type = "ON_DEMAND"  # 또는 "SPOT"
    
    k8s_labels = {
      Environment = "dev"
      NodeGroup   = "main"
    }
  }
}
```

#### 추가 노드 그룹 (SPOT 인스턴스)
```hcl
node_groups = {
  main = {
    # ... 기본 설정
  },
  spot = {
    name           = "spot"
    instance_types = ["t3.medium", "t3.large"]
    
    min_size     = 0
    max_size     = 10
    desired_size = 2
    
    capacity_type = "SPOT"  # SPOT 인스턴스로 비용 절약
    
    k8s_labels = {
      Environment = "dev"
      NodeGroup   = "spot"
      InstanceType = "spot"
    }
  }
}
```

## 📊 배포 후 확인

## 📊 배포 후 확인

### 1. 클러스터 상태 확인
```bash
# 노드 상태 확인
kubectl get nodes -o wide

# 모든 네임스페이스의 Pod 상태 확인
kubectl get pods -A

# 클러스터 정보 확인
kubectl cluster-info
```

### 2. EKS 애드온 상태 확인
```bash
# AWS Load Balancer Controller 확인
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# External DNS 확인
kubectl get deployment -n kube-system external-dns
kubectl logs -n kube-system deployment/external-dns

# Cluster Autoscaler 확인
kubectl get deployment -n kube-system cluster-autoscaler
kubectl logs -n kube-system deployment/cluster-autoscaler

# EBS CSI Driver 확인
kubectl get pods -n kube-system -l app=ebs-csi-controller
```

### 3. 스토리지 클래스 확인
```bash
# StorageClass 목록 확인
kubectl get storageclass

# GP3가 기본 StorageClass인지 확인
kubectl get storageclass gp3 -o yaml
```

### 4. 네트워크 연결 테스트
```bash
# 테스트 Pod 생성
kubectl run test-pod --image=nginx --rm -it --restart=Never -- /bin/bash

# Pod 내에서 인터넷 연결 테스트
curl -I https://www.google.com
```

### 5. IRSA 역할 확인
```bash
# ServiceAccount 확인
kubectl get serviceaccount -n kube-system aws-load-balancer-controller -o yaml
kubectl get serviceaccount -n kube-system external-dns -o yaml
kubectl get serviceaccount -n kube-system cluster-autoscaler -o yaml
```

## 🔍 트러블슈팅

### 일반적인 문제 해결

#### 1. Terraform 초기화 실패
```bash
# 캐시 정리 후 재시도
rm -rf .terraform .terraform.lock.hcl
terraform init
```

#### 2. 기존 리소스 없음 오류
```bash
# Route53 호스팅 존 확인
aws route53 list-hosted-zones --query "HostedZones[?Name=='your-domain.com.']"

# ACM 인증서 확인
aws acm list-certificates --region ap-northeast-2 --query "CertificateSummaryList[?DomainName=='your-domain.com']"
```

#### 3. 노드 그룹 생성 실패
```bash
# IAM 역할 정책 연결 상태 확인
aws iam list-attached-role-policies --role-name your-cluster-name-node-group-role

# 서브넷 가용성 확인
aws ec2 describe-subnets --subnet-ids subnet-xxxxx
```

#### 4. Helm 차트 설치 실패
```bash
# Helm 리포지토리 업데이트
helm repo update

# 특정 차트 상태 확인
helm list -n kube-system
helm status aws-load-balancer-controller -n kube-system
```

#### 5. kubectl 연결 실패
```bash
# kubeconfig 재설정
aws eks update-kubeconfig --region ap-northeast-2 --name your-cluster-name

# 클러스터 상태 확인
aws eks describe-cluster --name your-cluster-name --region ap-northeast-2
```

### 로그 확인 방법
```bash
# Terraform 로그 활성화
export TF_LOG=INFO
terraform apply

# AWS CLI 디버그 모드
aws eks describe-cluster --name your-cluster-name --debug
```

## 💰 비용 최적화

### 주요 비용 구성 요소

#### 1. EKS 클러스터 비용
- **EKS 컨트롤 플레인**: $0.10/시간 (~$73/월)
- **최적화 방법**: 개발 환경에서는 클러스터 공유 사용

#### 2. EC2 인스턴스 비용
- **t3.medium**: $0.0416/시간 (~$30/월/인스턴스)
- **최적화 방법**: 
  - SPOT 인스턴스 사용 (최대 90% 절약)
  - 적절한 인스턴스 크기 선택
  - Cluster Autoscaler로 자동 스케일링

#### 3. NAT Gateway 비용
- **NAT Gateway**: $0.045/시간 (~$32/월/개)
- **데이터 처리**: $0.045/GB
- **최적화 방법**: 
  - 개발 환경에서는 단일 NAT Gateway 사용
  - VPC 엔드포인트 활용으로 데이터 전송 비용 절약

#### 4. EBS 볼륨 비용
- **GP3**: $0.08/GB/월
- **최적화 방법**: 
  - 적절한 볼륨 크기 설정
  - 사용하지 않는 볼륨 정리

### 비용 절약 설정 예시
```hcl
# terraform.tfvars - 개발 환경용 비용 최적화 설정
node_groups = {
  spot = {
    name           = "spot"
    instance_types = ["t3.small", "t3.medium"]  # 더 작은 인스턴스
    
    min_size     = 1
    max_size     = 3
    desired_size = 1  # 최소 노드로 시작
    
    capacity_type = "SPOT"  # SPOT 인스턴스 사용
    
    k8s_labels = {
      Environment = "dev"
      NodeGroup   = "spot"
    }
  }
}
```

### 비용 모니터링
```bash
# AWS Cost Explorer API를 통한 비용 확인
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

## 🔒 보안 고려사항

### 네트워크 보안

#### 1. VPC 설계
- ✅ **프라이빗 서브넷**: 워커 노드를 프라이빗 서브넷에 배치
- ✅ **NAT Gateway**: 아웃바운드 인터넷 연결만 허용
- ✅ **보안 그룹**: 최소 권한 원칙 적용

#### 2. EKS 엔드포인트 보안
```bash
# 프라이빗 엔드포인트만 사용하도록 설정 (선택사항)
# main.tf에서 수정:
vpc_config {
  endpoint_private_access = true
  endpoint_public_access  = false  # 퍼블릭 접근 차단
  public_access_cidrs     = ["your-office-ip/32"]  # 특정 IP만 허용
}
```

### IAM 보안

#### 1. IRSA (IAM Role for Service Account)
- ✅ **최소 권한**: 각 서비스별 필요한 권한만 부여
- ✅ **역할 분리**: 서비스별 별도 IAM 역할 사용
- ✅ **임시 자격 증명**: STS 토큰 사용으로 보안 강화

#### 2. 노드 그룹 IAM 역할
```bash
# 노드 그룹 역할에 불필요한 권한이 없는지 확인
aws iam list-attached-role-policies --role-name your-cluster-name-node-group-role
```

### 데이터 보안

#### 1. 암호화
- ✅ **EBS 볼륨**: 저장 시 암호화 활성화
- ✅ **EKS Secrets**: etcd 암호화 (기본 활성화)
- ✅ **전송 중 암호화**: TLS 1.2+ 사용

#### 2. 시크릿 관리
```bash
# AWS Secrets Manager 또는 Parameter Store 사용 권장
kubectl create secret generic app-secret \
  --from-literal=database-password="$(aws secretsmanager get-secret-value --secret-id prod/db/password --query SecretString --output text)"
```

### 모니터링 및 로깅

#### 1. CloudWatch 로깅
- ✅ **EKS 컨트롤 플레인 로그**: API, Audit, Authenticator 등
- ✅ **애플리케이션 로그**: Fluent Bit 또는 CloudWatch Agent 사용

#### 2. 보안 모니터링
```bash
# AWS GuardDuty 활성화 (선택사항)
aws guardduty create-detector --enable

# AWS Config 규칙 설정 (선택사항)
aws configservice put-config-rule --config-rule file://eks-security-rules.json
```

### 정기 보안 점검

#### 1. 취약점 스캔
```bash
# 컨테이너 이미지 스캔
aws ecr start-image-scan --repository-name your-app --image-id imageTag=latest

# Kubernetes 보안 스캔 (kube-bench)
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
```

#### 2. 권한 검토
```bash
# 과도한 권한을 가진 ServiceAccount 확인
kubectl get clusterrolebindings -o wide
kubectl get rolebindings --all-namespaces -o wide
```

### 보안 모범 사례

1. **정기적인 업데이트**: Kubernetes 버전 및 노드 AMI 업데이트
2. **네트워크 정책**: Calico 또는 Cilium을 통한 Pod 간 통신 제어
3. **Pod Security Standards**: 보안 컨텍스트 및 정책 적용
4. **이미지 보안**: 신뢰할 수 있는 레지스트리 사용 및 이미지 스캔
5. **백업**: etcd 백업 및 재해 복구 계획 수립

## 🆚 기존 방식과의 차이점

기존 `eks-terraform` 디렉터리와의 주요 차이점:

| 구분 | 기존 방식 | 새로운 방식 |
|------|-----------|-------------|
| 구조 | 모듈 분리 | 단일 파일 통합 |
| 배포 | 2단계 (클러스터 → 애드온) | 1단계 (한번에) |
| Provider | 수동 구성 | 자동 구성 |
| 의존성 | 복잡한 관리 | 명확한 정의 |
| 안정성 | 애드온 설치 실패 가능 | 통합 배포로 안정성 향상 |

## ⚠️ 주의사항

1. **기존 리소스 요구사항**: 배포 전에 다음 리소스가 존재해야 합니다
   - Route53 호스팅 존: bluesunnywings.com
   - ACM 인증서: *.bluesunnywings.com (ISSUED 상태)
2. **배포 시간**: 전체 스택 배포에 15-20분 정도 소요됩니다
3. **비용**: NAT Gateway, EKS 클러스터, EC2 인스턴스 등의 비용이 발생합니다
4. **권한**: EKS, VPC, Route53, ACM 등의 AWS 서비스 권한이 필요합니다

## 🧹 리소스 정리

### 사전 준비
```bash
# 삭제 계획 확인
terraform plan -destroy
```

### 정리 실행
```bash
# 일반 실행
terraform destroy

# 백그라운드 실행 (권장)
nohup terraform destroy -auto-approve > ./log/"$(date +'%y%m%d_%H%M').tf_destroy.log" 2>&1 &
```

**백그라운드 실행 시:**
- 터미널 종료해도 삭제 계속 진행
- 로그는 `./log/` 디렉터리에 자동 저장
- `tail -f ./log/최신로그파일.log`로 진행 상황 확인

## 📁 파일 구조

```
bluesunnywings-eks-tf-sunny/
├── main.tf                    # 메인 Terraform 구성 (모든 리소스 정의)
├── variables.tf               # 변수 정의 (입력 매개변수)
├── outputs.tf                 # 출력값 정의 (배포 후 정보)
├── terraform.tfvars           # 변수 값 설정 (사용자 정의 값)
├── .terraform.lock.hcl        # Provider 버전 잠금 파일
├── .gitignore                 # Git 제외 파일
├── README.md                  # 이 문서
├── architecture.drawio        # 아키텍처 다이어그램
├── check-certificate.sh/      # 인증서 확인 스크립트
├── YAML/                      # 샘플 Kubernetes YAML 파일들
│   ├── ingress-example.yaml   # ALB Ingress 예제
│   ├── service-example.yaml   # Service 예제
│   └── deployment-example.yaml # Deployment 예제
└── Sample App with Monitoring/ # 모니터링이 포함된 샘플 애플리케이션
    ├── app-deployment.yaml
    ├── monitoring-stack.yaml
    └── grafana-dashboard.json
```

## 🔗 추가 리소스

### 공식 문서
- [AWS EKS 사용자 가이드](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Terraform AWS Provider 문서](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Kubernetes 공식 문서](https://kubernetes.io/docs/)

### EKS 애드온 문서
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [External DNS](https://github.com/kubernetes-sigs/external-dns)
- [Cluster Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler)
- [EBS CSI Driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver)

### 모범 사례 가이드
- [EKS 모범 사례 가이드](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes 보안 모범 사례](https://kubernetes.io/docs/concepts/security/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

---

**⚡ 빠른 배포를 위한 체크리스트:**

- [ ] AWS CLI 구성 완료
- [ ] Terraform 설치 완료
- [ ] kubectl 설치 완료
- [ ] Route53 호스팅 존 존재 확인
- [ ] ACM 인증서 ISSUED 상태 확인
- [ ] IAM 권한 확인
- [ ] `terraform.tfvars` 파일 설정
- [ ] `terraform init` 실행
- [ ] `terraform plan` 검토
- [ ] `terraform apply` 실행
- [ ] kubectl 설정 완료

**🎉 배포 완료 후 다음 단계:**
1. 클러스터 상태 확인
2. 애드온 동작 확인
3. 샘플 애플리케이션 배포
4. 모니터링 설정
5. 보안 정책 적용
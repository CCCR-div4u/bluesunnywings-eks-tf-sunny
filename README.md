# EKS Terraform One-Action Deployment

이 프로젝트는 AWS EKS 클러스터와 모든 필수 애드온을 한번에 배포하는 완전한 Terraform 구성입니다.

## 🏗️ 아키텍처 개요

### 네트워크 구성
- **VPC**: 10.0.0.0/16 CIDR 블록
- **가용 영역**: 2개 AZ에 걸친 고가용성 구성
- **퍼블릭 서브넷**: 10.0.0.0/24, 10.0.1.0/24 (ALB, NAT Gateway 배치)
- **프라이빗 서브넷**: 10.0.10.0/24, 10.0.11.0/24 (EKS 워커 노드 배치)
- **NAT Gateway**: 각 AZ별 배치로 고가용성 보장

### EKS 클러스터
- **Kubernetes 버전**: 1.32
- **엔드포인트**: 프라이빗 + 퍼블릭 접근 허용
- **로깅**: API, Audit, Authenticator, ControllerManager, Scheduler 활성화
- **OIDC Provider**: IRSA(IAM Role for Service Account) 지원

### 워커 노드
- **인스턴스 타입**: t3.small
- **Auto Scaling**: 최소 1대, 원하는 1대, 최대 3대
- **스토리지**: GP3 20GB
- **배치**: 프라이빗 서브넷만 사용

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

### 4. 도메인 & 인증서
- ✅ **Route53 호스팅 존**: bluesunnywings.com
- ✅ **ACM 인증서**: *.bluesunnywings.com (DNS 자동 검증)
- ✅ **자동 DNS 검증**: Route53 레코드 자동 생성

### 5. IAM 역할 (IRSA)
- ✅ **EKS 클러스터 서비스 역할**
- ✅ **노드 그룹 인스턴스 역할**
- ✅ **AWS Load Balancer Controller 역할**
- ✅ **External DNS 역할** (Route53 권한)
- ✅ **EBS CSI Driver 역할**

### 6. 스토리지
- ✅ **GP3 StorageClass** (기본값으로 설정)
- ✅ **볼륨 확장 지원**
- ✅ **암호화 활성화**

## 🚀 배포 방법

### 사전 요구사항
- AWS CLI 구성 완료
- Terraform >= 1.0 설치
- 적절한 AWS IAM 권한

### 1. 초기화
```bash
cd eks-terraform-one-action
terraform init
```

### 2. 변수 설정 (선택사항)
`terraform.tfvars` 파일을 수정하여 원하는 설정으로 변경:
```hcl
cluster_name = "your-cluster-name"
domain_name = "your-domain.com"
aws_region = "ap-northeast-2"
```

### 3. 계획 확인
```bash
terraform plan
```

### 4. 배포 실행
```bash
terraform apply
```

### 5. kubectl 설정
```bash
aws eks update-kubeconfig --region ap-northeast-2 --name bluesunnywings-eks
```

## 📊 배포 후 확인

### 클러스터 상태 확인
```bash
kubectl get nodes
kubectl get pods -A
```

### 애드온 상태 확인
```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl get deployment -n kube-system external-dns
```

### StorageClass 확인
```bash
kubectl get storageclass
```

## 🔍 주요 출력값

배포 완료 후 다음 정보들이 출력됩니다:
- EKS 클러스터 엔드포인트
- Route53 호스팅 존 ID
- ACM 인증서 ARN
- VPC 및 서브넷 정보
- IAM 역할 ARN들

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

1. **도메인 검증**: 첫 배포 시 ACM 인증서 DNS 검증에 시간이 소요될 수 있습니다
   - ACM 인증서 검증에 10분 타임아웃 설정으로 무한 대기 방지
   - 검증 실패 시 `Ctrl+C`로 안전하게 중단 후 재시도 가능
2. **배포 시간**: 전체 스택 배포에 15-20분 정도 소요됩니다
3. **비용**: NAT Gateway, EKS 클러스터, EC2 인스턴스 등의 비용이 발생합니다
4. **권한**: EKS, VPC, Route53, ACM 등의 AWS 서비스 권한이 필요합니다

## 🧹 리소스 정리

```bash
terraform destroy
```

## 📁 파일 구조

```
eks-terraform-one-action/
├── main.tf              # 메인 Terraform 구성
├── variables.tf         # 변수 정의
├── outputs.tf          # 출력값 정의
├── terraform.tfvars    # 변수 값 설정
├── architecture.drawio # 아키텍처 다이어그램
├── README.md           # 이 파일
└── .gitignore         # Git 제외 파일
```

## 🔗 관련 문서

- [AWS EKS 사용자 가이드](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [External DNS](https://github.com/kubernetes-sigs/external-dns)
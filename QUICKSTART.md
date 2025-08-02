# 🚀 EKS 클러스터 빠른 시작 가이드

이 가이드는 EKS 클러스터를 최대한 빠르게 배포하기 위한 단계별 지침입니다.

## ⚡ 5분 빠른 배포

### 1. 사전 확인
```bash
# 필수 도구 설치 확인
terraform version
aws --version
kubectl version --client

# AWS 자격 증명 확인
aws sts get-caller-identity
```

### 2. 기존 리소스 확인
```bash
# Route53 호스팅 존 확인
aws route53 list-hosted-zones --query "HostedZones[?Name=='bluesunnywings.com.']"

# ACM 인증서 확인
aws acm list-certificates --region ap-northeast-2 --query "CertificateSummaryList[?DomainName=='bluesunnywings.com']"
```

### 3. 배포 실행
```bash
# 1. 초기화
terraform init

# 2. 계획 확인 (선택사항)
terraform plan

# 3. 배포 실행 (백그라운드)
nohup terraform apply -auto-approve > ./log/"$(date +'%y%m%d_%H%M').tf.log" 2>&1 &

# 4. 진행 상황 확인
tail -f ./log/$(ls -t ./log/*.log | head -1)
```

### 4. 클러스터 접근 설정
```bash
# kubectl 설정
aws eks update-kubeconfig --region ap-northeast-2 --name bluesunnywings-eks

# 클러스터 상태 확인
kubectl get nodes
kubectl get pods -A
```

## 🔧 커스터마이징

### 기본 설정 변경
`terraform.tfvars` 파일을 수정하여 설정을 변경할 수 있습니다:

```hcl
# 클러스터 이름 변경
cluster_name = "my-eks-cluster"

# 도메인 변경 (기존 Route53 호스팅 존과 ACM 인증서 필요)
domain_name = "your-domain.com"

# 노드 그룹 설정 변경
node_groups = {
  main = {
    name           = "main"
    instance_types = ["t3.small"]  # 더 작은 인스턴스로 비용 절약
    min_size       = 1
    max_size       = 3
    desired_size   = 1
    capacity_type  = "SPOT"        # SPOT 인스턴스로 비용 절약
  }
}
```

## 📊 배포 완료 확인

### 필수 확인 사항
```bash
# 1. 노드 상태 확인
kubectl get nodes -o wide

# 2. 애드온 상태 확인
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl get deployment -n kube-system external-dns
kubectl get deployment -n kube-system cluster-autoscaler

# 3. 스토리지 클래스 확인
kubectl get storageclass
```

### 테스트 애플리케이션 배포
```bash
# 간단한 nginx 배포
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# 서비스 확인
kubectl get svc nginx
```

## 🧹 정리

### 리소스 삭제
```bash
# 테스트 애플리케이션 삭제
kubectl delete deployment nginx
kubectl delete service nginx

# 전체 인프라 삭제
terraform destroy -auto-approve
```

## ❗ 문제 해결

### 일반적인 오류
1. **Route53 호스팅 존 없음**: 도메인에 대한 호스팅 존을 먼저 생성하세요
2. **ACM 인증서 없음**: 도메인에 대한 SSL 인증서를 먼저 발급하세요
3. **권한 부족**: IAM 사용자에게 EKS, EC2, VPC 권한을 부여하세요

### 로그 확인
```bash
# Terraform 로그 확인
tail -f ./log/$(ls -t ./log/*.log | head -1)

# Kubernetes 이벤트 확인
kubectl get events --sort-by=.metadata.creationTimestamp
```

## 📚 더 자세한 정보

자세한 설정 옵션과 고급 기능은 [README.md](README.md)를 참조하세요.

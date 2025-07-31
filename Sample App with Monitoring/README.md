# Sample App with Monitoring

이 디렉터리는 EKS 클러스터에 Java 샘플 애플리케이션을 배포하고 Prometheus/Grafana 모니터링을 연동하는 완전한 가이드입니다.

## 📋 개요

### 테스트 환경 버전
- **EKS 클러스터**: Kubernetes 1.32
- **워커 노드**: t3.medium (2개)
- **Helm Charts**:
  - kube-prometheus-stack: 75.15.1 (App Version: v0.83.0)
  - grafana: 9.3.0 (App Version: 12.1.0) - kube-prometheus-stack에 포함
- **AWS Load Balancer Controller**: v2.6.2
- **JMX Exporter**: v0.19.0
- **스토리지**: EBS GP3 (기본 StorageClass)
- **네트워킹**: VPC CNI, CoreDNS, Kube-proxy

### 배포되는 구성 요소
- **Java 샘플 애플리케이션**: Spring Boot 기반 웹 애플리케이션
- **JMX 모니터링**: Heap 메모리, GC, 스레드 등 JVM 메트릭 수집
- **EBS 스토리지**: GP3 볼륨을 사용한 영구 스토리지
- **Prometheus**: 메트릭 수집 및 저장
- **Grafana**: 메트릭 시각화 대시보드
- **HTTPS Ingress**: ACM 인증서를 사용한 보안 연결

### 아키텍처
```
Internet → ALB (HTTPS) → EKS Pods
                      ├── Java App (8080) + JMX (7000)
                      ├── Prometheus (9090)
                      └── Grafana (3000)
```

## 🚀 배포 방법

### 사전 요구사항
- **EKS 클러스터**: Kubernetes 1.32 이상
- **AWS Load Balancer Controller**: v2.6.2 이상 설치됨
- **External DNS**: 설치 및 정상 동작
- **Helm**: v3.0 이상 설치됨
- **kubectl**: EKS 클러스터와 연결 설정 완료
- **ACM 인증서**: bluesunnywings.com 도메인 ISSUED 상태
- **Route53**: bluesunnywings.com 호스팅 존 존재

### 1. 파일 구조 확인
```
Sample App with Monitoring/
├── README.md                   # 이 문서
├── manifests/                  # Kubernetes 매니페스트
│   ├── jmx-configmap.yaml      # JMX Exporter 설정
│   ├── storage-test.yaml       # Java 앱 + JMX + 스토리지
│   ├── monitoring-ingress-single.yaml # 단일 ALB 모니터링 Ingress
│   └── jmx_exporter.values.yaml # Prometheus 설정
└── scripts/                    # 배포/정리 스크립트
    ├── deploy-commands.sh      # 배포 스크립트
    └── cleanup-commands.sh     # 정리 스크립트
```

### 2. 배포 실행
```bash
cd "Sample App with Monitoring/scripts"
chmod +x *.sh
./deploy-commands.sh
```

### 3. 배포 과정
1. **Helm 리포지토리 추가**:
   - prometheus-community/kube-prometheus-stack
   - grafana/grafana
2. **네임스페이스 생성**: monitoring 네임스페이스
3. **JMX 설정**: ConfigMap 생성 (JMX Exporter 0.19.0)
4. **Java 앱 배포**: 
   - 이미지: hnyeong/devsecops-pipeline-test:latest
   - JMX 포트: 7000, 앱 포트: 8080
   - EBS GP3 1GB 스토리지 마운트
5. **Prometheus Stack 설치**: 
   - Chart: kube-prometheus-stack v75.15.1
   - Prometheus v0.83.0 + Grafana v12.1.0 + AlertManager 통합
   - JMX 메트릭 수집 설정 포함
6. **Ingress 생성**: 
   - 단일 ALB로 다중 호스트 라우팅
   - prometheus.bluesunnywings.com, grafana.bluesunnywings.com
   - HTTPS 전용, ACM 인증서 자동 연결

## 🌐 접속 URL

배포 완료 후 다음 URL로 접속 가능:

- **샘플 애플리케이션**: https://www.bluesunnywings.com
- **Prometheus**: https://prometheus.bluesunnywings.com
- **Grafana**: https://grafana.bluesunnywings.com

## 🔐 Grafana 로그인

**기본 계정:**
- Username: `admin`
- Password: 다음 명령어로 확인
```bash
kubectl get secret --namespace monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode
```

## 📊 모니터링 메트릭

### JVM 메트릭 (포트 7000)
- **Heap 메모리**: 사용량, 최대값, 커밋된 메모리
- **Non-Heap 메모리**: 메타스페이스, 코드 캐시
- **가비지 컬렉션**: GC 횟수, 소요 시간
- **스레드**: 활성 스레드 수, 데몬 스레드
- **클래스 로딩**: 로드된 클래스 수

### 애플리케이션 메트릭 (포트 8080)
- **HTTP 요청**: 응답 시간, 상태 코드
- **데이터베이스**: 연결 풀, 쿼리 성능
- **비즈니스 메트릭**: 커스텀 메트릭

## 🗂️ 스토리지 테스트

### PVC 확인
```bash
kubectl get pvc
kubectl describe pvc java-app-storage
```

### 스토리지 테스트
```bash
# 파드에 접속
kubectl exec -it deployment/java-sample-app -- /bin/bash

# 데이터 쓰기
echo "Storage Test Data" > /app/data/test.txt

# 데이터 확인
cat /app/data/test.txt

# 파드 재시작 후 데이터 유지 확인
kubectl rollout restart deployment/java-sample-app
kubectl exec -it deployment/java-sample-app -- cat /app/data/test.txt
```

## 🔧 트러블슈팅

### 일반적인 문제

**1. Ingress 생성 실패**
```bash
kubectl describe ingress -A
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

**2. Prometheus 메트릭 수집 안됨**
```bash
kubectl logs -n monitoring deployment/prometheus-kube-prometheus-prometheus
kubectl get servicemonitor -n monitoring
```

**3. Grafana 접속 불가**
```bash
kubectl get pods -n monitoring
kubectl logs -n monitoring deployment/prometheus-grafana
```

### 상태 확인 명령어
```bash
# 전체 파드 상태
kubectl get pods -A

# Ingress 상태
kubectl get ingress -A

# 서비스 상태
kubectl get svc -A

# PVC 상태
kubectl get pvc
```

## 🧹 정리

### 리소스 정리
```bash
./cleanup-commands.sh
```

### 정리 과정
1. Helm 릴리스 삭제 (Prometheus Stack)
2. Ingress 삭제
3. Java 애플리케이션 삭제
4. ConfigMap 삭제

**⚠️ 중요**: Terraform destroy 실행 전에 반드시 cleanup을 먼저 실행해야 합니다.

## 📝 참고 사항

### 인프라 버전 정보
- **Terraform**: >= 1.0
- **AWS Provider**: ~> 5.0
- **Helm Provider**: ~> 2.10
- **Kubernetes Provider**: ~> 2.20
- **TLS Provider**: ~> 4.0

### 비용 최적화
- **t3.medium 인스턴스**: 충분한 파드 실행 공간
- **GP3 스토리지**: GP2 대비 20% 비용 절약
- **단일 ALB**: 모니터링 서비스를 하나의 ALB로 통합 ($16.2/월 절약)
- **NAT Gateway**: 고가용성을 위해 2개 AZ 사용

### 보안
- **HTTPS 전용**: 모든 트래픽 SSL/TLS 암호화
- **프라이빗 서브넷**: 워커 노드는 프라이빗 배치
- **IAM 역할**: IRSA를 통한 최소 권한 원칙

### 확장성
- **Auto Scaling**: 1-2-3 노드 자동 확장
- **HPA**: 파드 수평 확장 가능
- **모니터링**: 성능 기반 스케일링 결정

## 🔗 관련 문서

- [Prometheus 공식 문서](https://prometheus.io/docs/)
- [Grafana 공식 문서](https://grafana.com/docs/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [JMX Exporter](https://github.com/prometheus/jmx_exporter)
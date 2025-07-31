#!/bin/bash

echo "모니터링 스택 정리 중..."

# Helm 릴리스 삭제
helm uninstall prometheus -n monitoring

# Ingress 삭제
kubectl delete -f monitoring-ingress.yaml

# 기본 앱 삭제 (JMX + 스토리지 포함)
kubectl delete -f storage-test.yaml

# JMX 관련 리소스 삭제
kubectl delete -f jmx-configmap.yaml

# 네임스페이스 삭제 (선택사항)
# kubectl delete namespace monitoring

echo "정리 완료!"
echo "참고: Helm 리포지토리는 로컬 설정이므로 삭제하지 않았습니다."
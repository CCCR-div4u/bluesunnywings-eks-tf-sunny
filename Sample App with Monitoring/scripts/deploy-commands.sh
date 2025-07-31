#!/bin/bash

# Helm 리포지토리 추가
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# 네임스페이스 생성
kubectl create namespace monitoring

# JMX 모니터링 설정 (ConfigMap 먼저)
kubectl create -f ../manifests/jmx-configmap.yaml

# 기본 앱 배포 (JMX + 스토리지 포함)
kubectl create -f ../manifests/storage-test.yaml

# Prometheus Stack 설치 (Grafana 포함)
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  -f ../manifests/jmx_exporter.values.yaml

# Ingress 생성 (단일 ALB로 다중 호스트)
kubectl create -f ../manifests/monitoring-ingress-single.yaml

echo "배포 완료!"
echo "접속 URL:"
echo "- 샘플 앱: https://www.bluesunnywings.com"
echo "- Prometheus: https://prometheus.bluesunnywings.com"
echo "- Grafana: https://grafana.bluesunnywings.com"
echo ""
echo "Grafana 기본 로그인:"
echo "- Username: admin"
echo "- Password: $(kubectl get secret --namespace monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode)"
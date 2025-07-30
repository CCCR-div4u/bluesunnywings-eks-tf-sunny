#!/bin/bash

# ACM 인증서 상태 확인 및 도메인 검증 스크립트
# 사용법: ./scripts/check-certificate.sh [domain] [region]

set -e

DOMAIN_NAME=${1:-"bluesunnywings.com"}
AWS_REGION=${2:-"ap-northeast-2"}

echo "🔍 도메인 및 ACM 인증서 종합 검증 중..."
echo "도메인: $DOMAIN_NAME"
echo "리전: $AWS_REGION"
echo ""

# 1. 도메인 네임서버 확인
echo "🌐 1. 도메인 네임서버 확인"
echo "----------------------------------------"
DOMAIN_NS=$(dig +short NS $DOMAIN_NAME | head -4)
if [ -z "$DOMAIN_NS" ]; then
  echo "❌ 도메인 네임서버를 찾을 수 없습니다. 도메인이 올바르게 등록되었는지 확인하세요."
  exit 1
fi

echo "현재 도메인 네임서버:"
echo "$DOMAIN_NS"
echo ""

# 2. Route53 호스팅 존 확인
echo "🔗 2. Route53 호스팅 존 확인"
echo "----------------------------------------"
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones \
  --query "HostedZones[?Name=='$DOMAIN_NAME.'].Id" \
  --output text | cut -d'/' -f3)

if [ -z "$HOSTED_ZONE_ID" ]; then
  echo "❌ Route53 호스팅 존을 찾을 수 없습니다."
  echo "💡 해결방법: terraform apply로 호스팅 존을 먼저 생성하거나, use_existing_hosted_zone=true로 설정하세요."
  exit 1
fi

echo "✅ Route53 호스팅 존 ID: $HOSTED_ZONE_ID"

# Route53 네임서버 확인
R53_NS=$(aws route53 get-hosted-zone --id $HOSTED_ZONE_ID \
  --query 'DelegationSet.NameServers' --output text | tr '\t' '\n')

echo "Route53 네임서버:"
echo "$R53_NS"
echo ""

# 3. 네임서버 일치 여부 확인
echo "🔄 3. 네임서버 일치 여부 확인"
echo "----------------------------------------"
NS_MATCH=true
for ns in $R53_NS; do
  if ! echo "$DOMAIN_NS" | grep -q "$ns"; then
    NS_MATCH=false
    break
  fi
done

if [ "$NS_MATCH" = "true" ]; then
  echo "✅ 도메인 네임서버가 Route53과 일치합니다."
else
  echo "❌ 도메인 네임서버가 Route53과 일치하지 않습니다!"
  echo ""
  echo "💡 해결방법:"
  echo "도메인 등록업체에서 네임서버를 다음으로 변경하세요:"
  echo "$R53_NS"
  echo ""
  echo "⚠️  네임서버 변경 후 전파까지 최대 48시간이 소요될 수 있습니다."
fi
echo ""

# 4. ACM 인증서 확인 (현재 리전)
echo "📋 4. ACM 인증서 확인 (현재 리전: $AWS_REGION)"
echo "----------------------------------------"
check_certificate() {
  local region=$1
  local region_name=$2
  
  echo "[$region_name] 인증서 확인 중..."
  
  CERT_ARN=$(aws acm list-certificates \
    --region $region \
    --query "CertificateSummaryList[?DomainName=='$DOMAIN_NAME'].CertificateArn" \
    --output text)

  if [ -z "$CERT_ARN" ]; then
    echo "❌ [$region_name] 도메인 $DOMAIN_NAME 에 대한 ACM 인증서를 찾을 수 없습니다."
    return 1
  fi

  echo "📋 [$region_name] 인증서 ARN: $CERT_ARN"

  CERT_STATUS=$(aws acm describe-certificate \
    --certificate-arn $CERT_ARN \
    --region $region \
    --query 'Certificate.Status' \
    --output text)

  echo "📊 [$region_name] 인증서 상태: $CERT_STATUS"

  if [ "$CERT_STATUS" = "ISSUED" ]; then
    echo "✅ [$region_name] 인증서가 성공적으로 발급되었습니다!"
  elif [ "$CERT_STATUS" = "PENDING_VALIDATION" ]; then
    echo "⏳ [$region_name] 인증서가 검증 대기 중입니다."
    
    # DNS 검증 레코드 확인
    echo "🔍 [$region_name] DNS 검증 레코드:"
    aws acm describe-certificate \
      --certificate-arn $CERT_ARN \
      --region $region \
      --query 'Certificate.DomainValidationOptions[*].{Domain:DomainName,Name:ResourceRecord.Name,Value:ResourceRecord.Value,Type:ResourceRecord.Type,Status:ValidationStatus}' \
      --output table
    
    # 실제 DNS 레코드 존재 여부 확인
    VALIDATION_RECORD=$(aws acm describe-certificate \
      --certificate-arn $CERT_ARN \
      --region $region \
      --query 'Certificate.DomainValidationOptions[0].ResourceRecord.Name' \
      --output text)
    
    if [ -n "$VALIDATION_RECORD" ]; then
      echo "🔍 [$region_name] DNS 레코드 실제 확인:"
      if dig +short "$VALIDATION_RECORD" CNAME | grep -q .; then
        echo "✅ [$region_name] DNS 검증 레코드가 존재합니다."
      else
        echo "❌ [$region_name] DNS 검증 레코드가 존재하지 않습니다."
        echo "💡 Route53에서 레코드 생성을 확인하거나 terraform apply를 다시 실행하세요."
      fi
    fi
    
  elif [ "$CERT_STATUS" = "FAILED" ]; then
    echo "❌ [$region_name] 인증서 발급에 실패했습니다."
    aws acm describe-certificate \
      --certificate-arn $CERT_ARN \
      --region $region \
      --query 'Certificate.DomainValidationOptions[*].{Domain:DomainName,Status:ValidationStatus,FailureReason:FailureReason}' \
      --output table
  fi
  echo ""
}

# 현재 리전 확인
check_certificate $AWS_REGION "현재 리전"

# us-east-1 확인
check_certificate "us-east-1" "us-east-1"

# 5. 종합 진단 및 권장사항
echo "🎯 5. 종합 진단 및 권장사항"
echo "----------------------------------------"

if [ "$NS_MATCH" = "false" ]; then
  echo "🚨 우선순위 1: 도메인 네임서버를 Route53으로 변경하세요."
  echo "   이 문제가 해결되지 않으면 ACM 인증서 검증이 불가능합니다."
else
  echo "✅ 네임서버 설정이 올바릅니다."
  echo "💡 ACM 인증서가 여전히 Pending이라면:"
  echo "   1. terraform destroy 후 재배포"
  echo "   2. use_existing_hosted_zone=true 설정 후 재배포"
  echo "   3. 수동으로 DNS 레코드 확인 및 생성"
fi

echo ""
echo "🔧 유용한 명령어:"
echo "# 네임서버 확인: dig NS $DOMAIN_NAME"
echo "# DNS 전파 확인: dig @8.8.8.8 NS $DOMAIN_NAME"
echo "# 인증서 재생성: terraform taint aws_acm_certificate.main"
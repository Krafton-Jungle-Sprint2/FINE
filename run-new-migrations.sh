#!/bin/bash

echo "🚀 새로운 마이그레이션 실행 스크립트 시작..."

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 1. 현재 상태 확인
log_info "현재 Docker 컨테이너 상태 확인..."
sudo docker-compose ps

# 2. MySQL이 실행 중인지 확인
if ! sudo docker-compose ps mysql | grep -q "Up"; then
    log_error "MySQL이 실행 중이 아닙니다. 먼저 MySQL을 시작하세요."
    exit 1
fi

# 3. Prisma 클라이언트 재생성
log_info "Prisma 클라이언트 재생성 중..."
sudo docker-compose exec backend npx prisma generate

# 4. 새로운 마이그레이션 생성
log_info "새로운 마이그레이션 생성 중..."
sudo docker-compose exec backend npx prisma migrate dev --name add_new_features

# 5. 데이터베이스 스키마 동기화
log_info "데이터베이스 스키마 동기화 중..."
sudo docker-compose exec backend npx prisma db push

# 6. 시드 데이터 생성
log_info "시드 데이터 생성 중..."
sudo docker-compose exec backend node prisma/seed.js

# 7. 완료 메시지
echo ""
log_info "🎉 새로운 마이그레이션 완료!"
log_info "📊 추가된 테이블들:"
echo "  - user_profiles: 사용자 프로필 확장"
echo "  - workspace_settings: 워크스페이스 설정"
echo "  - chat_notifications: 채팅 알림 (이미 존재)"

# 8. Prisma Studio로 확인
log_info "Prisma Studio로 새로운 스키마를 확인할 수 있습니다:"
echo "  http://[EC2_IP]:5555"

# 9. 서비스 상태 확인
log_info "서비스 상태 확인..."
sudo docker-compose ps

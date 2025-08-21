#!/bin/bash

echo "🔧 Prisma 마이그레이션 초기화 스크립트 시작..."

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

# 1. MySQL이 실행 중인지 확인
log_info "MySQL 컨테이너 상태 확인..."
if ! sudo docker-compose ps mysql | grep -q "Up"; then
    log_error "MySQL이 실행 중이 아닙니다. 먼저 MySQL을 시작하세요."
    exit 1
fi

# 2. MySQL 연결 테스트
log_info "MySQL 연결 테스트..."
if ! sudo docker-compose exec mysql mysqladmin ping -h 127.0.0.1 -uroot -prootpassword > /dev/null 2>&1; then
    log_error "MySQL에 연결할 수 없습니다. MySQL이 완전히 준비될 때까지 기다리세요."
    exit 1
fi

log_info "✅ MySQL 연결 성공!"

# 3. 데이터베이스 생성 확인
log_info "데이터베이스 생성 확인..."
sudo docker-compose exec mysql mysql -uroot -prootpassword -e "CREATE DATABASE IF NOT EXISTS team_collaboration;"
sudo docker-compose exec mysql mysql -uroot -prootpassword -e "CREATE DATABASE IF NOT EXISTS team_collaboration_shadow;"

# 4. Prisma 클라이언트 생성
log_info "Prisma 클라이언트 생성 중..."
cd backend
sudo docker-compose exec backend npx prisma generate

# 5. 기존 마이그레이션 파일 확인
log_info "기존 마이그레이션 파일 확인..."
if [ -d "prisma/migrations" ] && [ "$(ls -A prisma/migrations)" ]; then
    log_info "기존 마이그레이션 파일이 발견되었습니다."
    
    # 6. 마이그레이션 적용
    log_info "기존 마이그레이션 적용 중..."
    sudo docker-compose exec backend npx prisma migrate deploy
else
    log_warn "마이그레이션 파일이 없습니다. 새로운 마이그레이션을 생성합니다."
    
    # 7. 초기 마이그레이션 생성
    log_info "초기 마이그레이션 생성 중..."
    sudo docker-compose exec backend npx prisma migrate dev --name init
fi

# 8. 데이터베이스 스키마 동기화
log_info "데이터베이스 스키마 동기화 중..."
sudo docker-compose exec backend npx prisma db push

# 9. 시드 데이터 생성
log_info "시드 데이터 생성 중..."
sudo docker-compose exec backend node prisma/seed.js

# 10. Prisma Studio 시작 (선택사항)
log_info "Prisma Studio 시작 중..."
sudo docker-compose up prisma-studio -d

# 11. 완료 메시지
echo ""
log_info "🎉 Prisma 초기화 완료!"
log_info "📊 다음 단계:"
echo "1. 백엔드 서비스 시작: sudo docker-compose up backend -d"
echo "2. 전체 서비스 상태 확인: sudo docker-compose ps"
echo "3. 로그 확인: sudo docker-compose logs -f backend"
echo "4. Prisma Studio 접속: http://[EC2_IP]:5555"

cd ..

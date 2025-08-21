#!/bin/bash

echo "🔧 Prisma 설정 문제 해결 스크립트 시작..."

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

# 1. 잘못된 설정 파일 제거
log_info "잘못된 Prisma 설정 파일 제거 중..."
if [ -f "backend/prisma.config.js" ]; then
    sudo rm backend/prisma.config.js
    log_info "✅ prisma.config.js 파일이 제거되었습니다."
else
    log_info "✅ prisma.config.js 파일이 이미 없습니다."
fi

# 2. 모든 컨테이너 중지
log_info "모든 컨테이너 중지 중..."
sudo docker-compose down

# 3. Docker 시스템 정리
log_info "Docker 시스템 정리 중..."
sudo docker system prune -f

# 4. .env 파일 확인
log_info ".env 파일 확인 중..."
if [ ! -f ".env" ]; then
    log_warn ".env 파일이 없습니다. 생성합니다..."
    cat > .env << EOF
# 데이터베이스 설정
DATABASE_URL=mysql://root:rootpassword@mysql:3306/team_collaboration
SHADOW_DATABASE_URL=mysql://root:rootpassword@mysql:3306/team_collaboration_shadow

# JWT 시크릿 키
JWT_SECRET=ec2_jwt_secret_key_2024_secure
ACCESS_TOKEN_SECRET=ec2_access_token_secret_2024_secure
REFRESH_TOKEN_SECRET=ec2_refresh_token_secret_2024_secure

# 토큰 만료 시간
ACCESS_TOKEN_EXPIRY=15m
REFRESH_TOKEN_EXPIRY=7d

# 서버 포트
API_PORT=4000
SOCKET_PORT=5000

# 환경 설정
NODE_ENV=production
FRONTEND_URL=http://localhost:5173

# 데이터베이스 연결 설정
DATABASE_POOL_SIZE=5
DATABASE_CONNECTION_TIMEOUT=30000
DATABASE_QUERY_TIMEOUT=30000

# 타임존
TZ=Asia/Seoul
EOF
    log_info "✅ .env 파일이 생성되었습니다."
fi

# 5. MySQL만 먼저 시작
log_info "MySQL 컨테이너 시작 중..."
sudo docker-compose up mysql -d

# 6. MySQL 준비 대기
log_info "MySQL이 완전히 준비될 때까지 대기 중... (45초)"
sleep 45

# 7. MySQL 상태 확인
log_info "MySQL 상태 확인..."
if sudo docker-compose exec mysql mysqladmin ping -h 127.0.0.1 -uroot -prootpassword > /dev/null 2>&1; then
    log_info "✅ MySQL이 정상적으로 실행 중입니다."
else
    log_warn "⚠️  MySQL이 아직 준비되지 않았습니다. 추가로 30초 대기..."
    sleep 30
fi

# 8. 데이터베이스 생성 확인
log_info "데이터베이스 생성 확인..."
sudo docker-compose exec mysql mysql -uroot -prootpassword -e "CREATE DATABASE IF NOT EXISTS team_collaboration;"
sudo docker-compose exec mysql mysql -uroot -prootpassword -e "CREATE DATABASE IF NOT EXISTS team_collaboration_shadow;"

# 9. 백엔드 시작
log_info "백엔드 컨테이너 시작 중..."
sudo docker-compose up backend -d

# 10. 백엔드 준비 대기
log_info "백엔드 준비 대기 중... (30초)"
sleep 30

# 11. 백엔드 상태 확인
log_info "백엔드 상태 확인..."
if sudo docker-compose ps backend | grep -q "Up"; then
    log_info "✅ 백엔드가 정상적으로 실행 중입니다!"
    
    # 12. Prisma Studio 시작
    log_info "Prisma Studio 시작 중..."
    sudo docker-compose up prisma-studio -d
    
    # 13. 헬스체크
    log_info "헬스체크 실행..."
    sleep 10
    if curl -f http://localhost:4000/health > /dev/null 2>&1; then
        log_info "✅ 백엔드 API가 정상적으로 응답합니다!"
    else
        log_warn "⚠️  백엔드 API가 아직 준비되지 않았습니다."
    fi
else
    log_error "❌ 백엔드가 여전히 문제가 있습니다."
    log_info "로그를 확인하려면: sudo docker-compose logs -f backend"
fi

# 14. 최종 상태 확인
echo ""
log_info "🎉 Prisma 설정 문제 해결 완료!"
log_info "📊 최종 상태:"
sudo docker-compose ps

echo ""
log_info "📝 유용한 명령어:"
echo "  - 백엔드 로그: sudo docker-compose logs -f backend"
echo "  - MySQL 로그: sudo docker-compose logs -f mysql"
echo "  - 전체 재시작: sudo docker-compose restart"
echo "  - 서비스 중지: sudo docker-compose down"

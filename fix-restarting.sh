#!/bin/bash

echo "🔧 백엔드 restarting 문제 해결 스크립트 시작..."

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
docker-compose ps

# 2. 모든 컨테이너 중지
log_info "모든 컨테이너 중지 중..."
docker-compose down

# 3. Docker 시스템 정리
log_info "Docker 시스템 정리 중..."
docker system prune -f

# 4. .env 파일 확인
if [ ! -f ".env" ]; then
    log_warn ".env 파일이 없습니다. .env.example을 복사해서 생성합니다..."
    if [ -f ".env.example" ]; then
        cp .env.example .env
        log_info ".env 파일이 생성되었습니다. 필요한 값들을 설정하세요."
    else
        log_error ".env.example 파일이 없습니다. 수동으로 .env 파일을 생성하세요."
        echo "필수 환경 변수:"
        echo "DATABASE_URL=mysql://root:rootpassword@mysql:3306/team_collaboration"
        echo "JWT_SECRET=your_jwt_secret"
        echo "ACCESS_TOKEN_SECRET=your_access_secret"
        echo "REFRESH_TOKEN_SECRET=your_refresh_secret"
        read -p "환경 변수 설정 완료 후 Enter를 누르세요..."
    fi
fi

# 5. MySQL만 먼저 시작
log_info "MySQL 컨테이너 시작 중..."
docker-compose up mysql -d

# 6. MySQL 준비 대기
log_info "MySQL이 완전히 준비될 때까지 대기 중... (30초)"
sleep 30

# 7. MySQL 상태 확인
log_info "MySQL 상태 확인..."
if docker-compose exec mysql mysqladmin ping -h 127.0.0.1 -uroot -prootpassword > /dev/null 2>&1; then
    log_info "✅ MySQL이 정상적으로 실행 중입니다."
else
    log_warn "⚠️  MySQL이 아직 준비되지 않았습니다. 추가로 30초 대기..."
    sleep 30
fi

# 8. 백엔드 시작
log_info "백엔드 컨테이너 시작 중..."
docker-compose up backend -d

# 9. 백엔드 로그 확인
log_info "백엔드 로그 확인 중... (10초간)"
sleep 10
docker-compose logs --tail=50 backend

# 10. 최종 상태 확인
log_info "최종 상태 확인..."
docker-compose ps

# 11. 헬스체크
log_info "헬스체크 실행..."
sleep 5
if curl -f http://localhost:4000/health > /dev/null 2>&1; then
    log_info "✅ 백엔드 API가 정상적으로 응답합니다!"
else
    log_warn "⚠️  백엔드 API가 아직 준비되지 않았습니다."
    log_info "로그를 확인하려면: docker-compose logs -f backend"
fi

echo ""
log_info "문제 해결 완료!"
log_info "추가 문제가 있다면 다음 명령어로 로그를 확인하세요:"
echo "  docker-compose logs -f backend"
echo "  docker-compose logs -f mysql"

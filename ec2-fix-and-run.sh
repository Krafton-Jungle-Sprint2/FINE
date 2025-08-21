#!/bin/bash

echo "🚀 EC2 Docker 문제 해결 및 서버 실행 스크립트 시작..."

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
log_info "현재 Docker 상태 확인..."
sudo docker ps -a
sudo docker volume ls

# 2. 모든 컨테이너 중지
log_info "모든 컨테이너 중지 중..."
sudo docker-compose down

# 3. 문제가 되는 볼륨들 완전 제거
log_info "문제가 되는 볼륨들 제거 중..."
sudo docker volume rm fine_node_modules fine_mysql_data 2>/dev/null || true
sudo docker volume rm $(sudo docker volume ls -q | grep fine_) 2>/dev/null || true

# 4. Docker 시스템 완전 정리
log_info "Docker 시스템 완전 정리 중..."
sudo docker system prune -af --volumes

# 5. 디렉토리 권한 확인 및 수정
log_info "디렉토리 권한 확인 및 수정 중..."
sudo chown -R ubuntu:ubuntu .
chmod -R 755 .

# 6. .env 파일 확인
if [ ! -f ".env" ]; then
    log_warn ".env 파일이 없습니다. 기본 환경 변수로 생성합니다..."
    cat > .env << EOF
# 데이터베이스 설정
DATABASE_URL=mysql://root:rootpassword@mysql:3306/team_collaboration
SHADOW_DATABASE_URL=mysql://root:rootpassword@mysql:3306/team_collaboration_shadow

# JWT 시크릿 키
JWT_SECRET=ec2_jwt_secret_key_2024
ACCESS_TOKEN_SECRET=ec2_access_token_secret_2024
REFRESH_TOKEN_SECRET=ec2_refresh_token_secret_2024

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
DATABASE_POOL_SIZE=10
DATABASE_CONNECTION_TIMEOUT=30000
DATABASE_QUERY_TIMEOUT=30000

# 타임존
TZ=Asia/Seoul
EOF
    log_info "✅ .env 파일이 생성되었습니다."
fi

# 7. MySQL만 먼저 시작
log_info "MySQL 컨테이너 시작 중..."
sudo docker-compose up mysql -d

# 8. MySQL 준비 대기
log_info "MySQL이 완전히 준비될 때까지 대기 중... (45초)"
sleep 45

# 9. MySQL 상태 확인
log_info "MySQL 상태 확인..."
if sudo docker-compose exec mysql mysqladmin ping -h 127.0.0.1 -uroot -prootpassword > /dev/null 2>&1; then
    log_info "✅ MySQL이 정상적으로 실행 중입니다."
else
    log_warn "⚠️   MySQL이 아직 준비되지 않았습니다. 추가로 30초 대기..."
    sleep 30
fi

# 10. 백엔드 시작
log_info "백엔드 컨테이너 시작 중..."
sudo docker-compose up backend -d

# 11. 백엔드 준비 대기
log_info "백엔드 준비 대기 중... (20초)"
sleep 20

# 12. Prisma Studio 시작 (선택사항)
log_info "Prisma Studio 시작 중..."
sudo docker-compose up prisma-studio -d

# 13. 최종 상태 확인
log_info "최종 상태 확인..."
sudo docker-compose ps

# 14. 헬스체크
log_info "헬스체크 실행..."
sleep 10
if curl -f http://localhost:4000/health > /dev/null 2>&1; then
    log_info "✅ 백엔드 API가 정상적으로 응답합니다!"
else
    log_warn "⚠️  백엔드 API가 아직 준비되지 않았습니다."
    log_info "로그를 확인하려면: sudo docker-compose logs -f backend"
fi

# 15. 서비스 URL 정보
echo ""
log_info "🎉 서버 실행 완료!"
log_info "📊 서비스 정보:"
echo "  - Backend API: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):4000"
echo "  - Socket.IO: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):5000"
echo "  - Prisma Studio: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):5555"
echo "  - MySQL: localhost:3307"
echo ""
log_info "📝 유용한 명령어:"
echo "  - 로그 확인: sudo docker-compose logs -f [service_name]"
echo "  - 서비스 중지: sudo docker-compose down"
echo "  - 서비스 재시작: sudo docker-compose restart [service_name]"
echo "  - 전체 재시작: sudo docker-compose down && sudo docker-compose up -d"

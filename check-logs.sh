#!/bin/bash

echo "🔍 상세 로그 분석 스크립트 시작..."

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# 1. 컨테이너 상태 확인
echo "=========================================="
log_info "1. 컨테이너 상태 확인"
echo "=========================================="
sudo docker-compose ps

echo ""
echo "=========================================="
log_info "2. 백엔드 상세 로그 (최근 100줄)"
echo "=========================================="
sudo docker-compose logs --tail=100 backend

echo ""
echo "=========================================="
log_info "3. MySQL 상세 로그 (최근 50줄)"
echo "=========================================="
sudo docker-compose logs --tail=50 mysql

echo ""
echo "=========================================="
log_info "4. Prisma Studio 로그 (최근 30줄)"
echo "=========================================="
sudo docker-compose logs --tail=30 prisma-studio

echo ""
echo "=========================================="
log_info "5. 백엔드 오류 로그만 필터링"
echo "=========================================="
sudo docker-compose logs backend | grep -i "error\|fail\|exception\|crash" | tail -20

echo ""
echo "=========================================="
log_info "6. MySQL 오류 로그만 필터링"
echo "=========================================="
sudo docker-compose logs mysql | grep -i "error\|fail\|exception" | tail -20

echo ""
echo "=========================================="
log_info "7. 백엔드 시작/종료 패턴 분석"
echo "=========================================="
sudo docker-compose logs backend | grep -E "(Starting|Started|Stopping|Stopped|Restarting|Exit)" | tail -20

echo ""
echo "=========================================="
log_info "8. 메모리 및 리소스 사용량"
echo "=========================================="
sudo docker stats --no-stream

echo ""
echo "=========================================="
log_info "9. Docker 볼륨 상태"
echo "=========================================="
sudo docker volume ls

echo ""
echo "=========================================="
log_info "10. 네트워크 상태"
echo "=========================================="
sudo docker network ls

echo ""
echo "=========================================="
log_info "📝 로그 분석 완료!"
echo "=========================================="
log_info "추가 분석이 필요한 경우:"
echo "  - 실시간 로그: sudo docker-compose logs -f [service_name]"
echo "  - 특정 시간: sudo docker-compose logs --since='1h' [service_name]"
echo "  - 오류만: sudo docker-compose logs [service_name] | grep -i 'error'"
echo "  - 전체 로그: sudo docker-compose logs [service_name] > logs.txt"

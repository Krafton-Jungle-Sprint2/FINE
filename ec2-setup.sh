#!/bin/bash

echo "🚀 EC2 자동 설정 및 배포 스크립트 시작..."

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 함수: 로그 출력
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 1. 시스템 업데이트
log_info "시스템 업데이트 중..."
sudo yum update -y

# 2. Docker 설치
log_info "Docker 설치 중..."
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# 3. Docker Compose 설치
log_info "Docker Compose 설치 중..."
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 4. Git 설치
log_info "Git 설치 중..."
sudo yum install -y git

# 5. SSH 키 생성 (기존 키가 없는 경우)
if [ ! -f ~/.ssh/id_rsa ]; then
    log_info "SSH 키 생성 중..."
    ssh-keygen -t rsa -b 4096 -C "ec2-user@ec2" -f ~/.ssh/id_rsa -N ""
    log_warn "생성된 공개키를 GitHub/GitLab에 등록해야 합니다:"
    echo "=========================================="
    cat ~/.ssh/id_rsa.pub
    echo "=========================================="
    log_warn "위 공개키를 복사해서 Git 저장소에 등록한 후 Enter를 누르세요..."
    read -p "공개키 등록 완료 후 Enter를 누르세요..."
else
    log_info "기존 SSH 키가 발견되었습니다."
fi

# 6. Git 설정
log_info "Git 설정 중..."
git config --global user.name "EC2-User"
git config --global user.email "ec2-user@ec2"

# 7. 프로젝트 디렉토리 생성 및 이동
PROJECT_DIR="/home/ec2-user/codea"
log_info "프로젝트 디렉토리 생성: $PROJECT_DIR"
mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

# 8. Git 저장소 클론 (사용자 입력 필요)
log_warn "Git 저장소 URL을 입력하세요 (예: git@github.com:username/repository.git)"
read -p "Git 저장소 URL: " GIT_REPO_URL

if [ -n "$GIT_REPO_URL" ]; then
    log_info "Git 저장소 클론 중: $GIT_REPO_URL"
    git clone $GIT_REPO_URL .
    
    if [ $? -eq 0 ]; then
        log_info "저장소 클론 성공!"
    else
        log_error "저장소 클론 실패. SSH 키가 올바르게 등록되었는지 확인하세요."
        exit 1
    fi
else
    log_warn "Git 저장소 URL이 입력되지 않았습니다. 수동으로 클론하세요."
fi

# 9. 환경 변수 파일 설정
log_info "환경 변수 파일 설정 중..."
if [ -f ".env.example" ]; then
    cp .env.example .env
    log_warn ".env 파일이 생성되었습니다. 필요한 값들을 설정하세요."
    log_warn "편집기로 .env 파일을 열어서 설정값을 입력하세요."
    read -p "환경 변수 설정 완료 후 Enter를 누르세요..."
else
    log_warn ".env.example 파일이 없습니다. 수동으로 .env 파일을 생성하세요."
fi

# 10. Docker 권한 설정
log_info "Docker 권한 설정 중..."
newgrp docker

# 11. 애플리케이션 배포
log_info "애플리케이션 배포 시작..."
if [ -f "backend/src/scritpts/deploy.sh" ]; then
    chmod +x backend/src/scritpts/deploy.sh
    ./backend/src/scritpts/deploy.sh
else
    log_warn "deploy.sh 스크립트를 찾을 수 없습니다. 수동으로 배포하세요."
    log_info "수동 배포 명령어:"
    echo "docker-compose up -d"
fi

# 12. 완료 메시지
log_info "EC2 설정 완료!"
log_info "다음 단계:"
echo "1. .env 파일에서 환경 변수 설정"
echo "2. docker-compose up -d 로 애플리케이션 실행"
echo "3. http://[EC2_IP]:4000 에서 API 확인"
echo "4. http://[EC2_IP]:5555 에서 Prisma Studio 확인"

# 13. 현재 상태 확인
log_info "현재 상태 확인:"
docker --version
docker-compose --version
git --version

echo "�� EC2 설정이 완료되었습니다!"

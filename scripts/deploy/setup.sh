#!/bin/bash

# 스크립트가 있는 디렉토리의 절대 경로를 구합니다
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# 필요한 디렉토리 생성
mkdir -p "$PROJECT_ROOT/config/dev"
mkdir -p "$PROJECT_ROOT/config/prod"
mkdir -p "$PROJECT_ROOT/logs"
mkdir -p "$PROJECT_ROOT/docker/kamailio"
mkdir -p "$PROJECT_ROOT/docker/dev"
mkdir -p "$PROJECT_ROOT/docker/prod"

# 개발 환경 설정
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    cat > "$PROJECT_ROOT/.env" << EOF
KAMAILIO_DEBUG=1
MYSQL_ROOT_PASSWORD=rootpassword
MYSQL_DATABASE=kamailio
MYSQL_USER=kamailio
MYSQL_PASSWORD=kamailiopass
EOF
fi

# 실행 권한 부여
chmod +x "$SCRIPT_DIR"/*.sh
chmod +x "$PROJECT_ROOT/scripts/monitoring"/*.sh
chmod +x "$PROJECT_ROOT/scripts/maintenance"/*.sh

echo "Setup completed successfully!" 
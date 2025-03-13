# OpenManus-kamailio

Kamailio 기반의 OpenManus 프로젝트입니다.

## 프로젝트 구조

```
.
├── config/           # Kamailio 설정 파일
│   ├── kamailio.cfg
│   └── kamctlrc
├── scripts/         # 운영 및 관리 스크립트
│   ├── deploy/
│   └── monitoring/
├── modules/         # 커스텀 Kamailio 모듈
├── docs/           # 프로젝트 문서
├── tests/          # 테스트 코드
└── docker/         # 도커 관련 파일
```

## 시작하기

### 필수 조건
- Kamailio 5.x 이상
- Docker & Docker Compose
- Make

### 설치 방법
1. 저장소 클론
```bash
git clone https://github.com/your-username/OpenManus-kamailio.git
cd OpenManus-kamailio
```

2. 개발 환경 설정
```bash
make setup
```

3. 서비스 실행
```bash
make run
```

## 문서
자세한 설치 및 설정 가이드는 [docs](./docs) 디렉토리를 참조하세요.

## 라이선스
이 프로젝트는 MIT 라이선스로 제공됩니다.
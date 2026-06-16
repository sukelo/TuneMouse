#!/usr/bin/env bash
# 기존 인스턴스 종료 후 .app 실행
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="TuneMouse"
APP="$ROOT/dist/$APP_NAME.app"

if [[ ! -d "$APP" ]]; then
    echo "!! $APP 가 없음. 먼저 ./scripts/build.sh 실행" >&2
    exit 1
fi

echo "==> 기존 인스턴스 종료"
pkill -x "$APP_NAME" 2>/dev/null || true

echo "==> 실행: $APP"
open "$APP"

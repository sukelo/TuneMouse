#!/usr/bin/env bash
# TuneMouse 로컬 개발 빌드: swift build → .app 번들 조립 → 코드 서명
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="TuneMouse"
CONFIG="${CONFIG:-debug}"          # CONFIG=release ./scripts/build.sh 로 릴리스 빌드
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"

echo "==> swift build ($CONFIG)"
swift build -c "$CONFIG"

BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
BIN="$BIN_DIR/$APP_NAME"
if [[ ! -x "$BIN" ]]; then
    echo "!! 빌드 산출물을 찾을 수 없음: $BIN" >&2
    exit 1
fi

echo "==> .app 번들 조립: $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Packaging/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# 코드 서명 정체성 결정 순서:
#   1) 환경변수 CODESIGN_IDENTITY 가 있으면 그것을 사용
#   2) 없으면 키체인에서 self-signed 인증서(기본 이름 "TuneMouse Dev")를 자동 탐색
#   3) 둘 다 없으면 ad-hoc("-") — 동작은 하나 리빌드 시 권한 재허용 가능성
# 인증서 생성법: docs/signing.md 참고
DEV_CERT_NAME="${DEV_CERT_NAME:-TuneMouse Dev}"
if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
    IDENTITY="$CODESIGN_IDENTITY"
# -v(valid) 미사용: self-signed 인증서는 신뢰 미설정이라 -v 목록엔 안 뜬다.
# 서명에는 문제없으므로 정책 목록 전체에서 이름으로 탐지한다.
elif security find-identity -p codesigning 2>/dev/null | grep -qF "$DEV_CERT_NAME"; then
    IDENTITY="$DEV_CERT_NAME"
else
    IDENTITY="-"
fi
echo "==> codesign (identity: $IDENTITY)"
codesign --force --sign "$IDENTITY" "$APP"

echo "==> 완료: $APP"

# Phase 0 마무리 — 다듬기 권장안

> Phase 0 골격(메뉴바/설정/권한/빌드·서명)은 검증 완료. 이벤트 탭(Phase 1)으로 넘어가기 전,
> **탭과 독립적이고 토대로서 가치 있는 항목**만 골라 다듬는다.

## 지금 처리 (권장)

### 1. 로그인 시 자동 시작 (`SMAppService`)
- `SMAppService.mainApp` 의 `register()`/`unregister()` (macOS 13+ 표준, 헬퍼 앱 불필요).
- `Sources/TuneMouse/Login/LoginItemManager.swift` — 등록/해제 + 상태 조회.
- `AppState.launchAtLogin` (진실 소스 = `SMAppService.status`), 설정창에 토글.
- 전제: 서명된 `.app` 번들 필요 → self-signed 번들로 충족.

### 2. README
- 한 줄 소개 + 핵심 제약(접근성 권한 / 트랙패드 미관여 / 앱스토어 불가) + 빌드·실행 + 서명 + 문서 링크.

### 3. 로깅 토대 (`os.Logger`)
- `Sources/TuneMouse/Support/Log.swift` — subsystem `com.tunemouse.TuneMouse`, 카테고리 `app`/`permission`/`menu` (추후 `tap`/`scroll` 확장).
- 앱 시작 · 권한 상태 변화 · 토글 지점 로그 → Phase 1 탭 디버깅 토대.

### 4. 선택 폴리시 (작음)
- 꺼짐 상태 아이콘 흐리게(`alphaValue`) + tooltip(켜짐/꺼짐).
- 메뉴 헤더에 버전 표시(`TuneMouse vX.Y.Z`, `CFBundleShortVersionString`).

## Phase 1로 넘김 (지금 안 함)
- **패닉 키(전역 토글 핫키)** — 끌 대상(탭)이 생긴 뒤라야 의미 있음.
- **활성화 토글 실제 동작** — 탭에 연결.

## 작업 후
빌드·실행 검증 → `docs/phase-0-setup.md` 체크리스트 갱신 → 커밋.

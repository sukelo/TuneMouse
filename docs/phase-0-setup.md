# Phase 0 — 셋업 작업 파일

> 목표: **"빈 껍데기지만 실행되고, 메뉴바에 뜨고, 접근성 권한까지 잡히는 앱"** 을 SwiftPM로 만든다.
> 이벤트 탭/기능은 Phase 1 이후. 여기서는 토대와 빌드/실행 워크플로우만 완성한다.
> 관련 결정사항은 [SPEC.md](../SPEC.md) 참조.

## Definition of Done (완료 기준)

- [x] `./scripts/build.sh` 한 방으로 `TuneMouse.app` 빌드 + 서명까지 완료된다. *(ad-hoc 서명, 검증됨)*
- [x] 앱 실행 시 Dock 없이 **메뉴바에 아이콘**이 뜬다. *(사용자 확인 완료)*
- [x] 메뉴에 **활성화 토글 / 설정 열기 / 종료** 가 있다. *(사용자 확인 완료)*
- [x] 설정 창(SwiftUI)이 열리고 **접근성 권한 상태**가 보인다 (허용/미허용). *(사용자 확인 완료)*
- [x] 권한 미허용 시 **시스템 설정 바로가기** 버튼이 동작한다. *(사용자 확인 완료)*
- [x] 리빌드해도 self-signed 서명 정체성이 안정적이라 **권한 재허용이 불필요**하다. *(self-signed 인증서 "TuneMouse Dev"로 서명 적용 완료, Authority 확인됨. 실제 권한 영속성은 Phase 1에서 탭+권한 사용 시 검증)*

---

## 작업 항목

### 1. 프로젝트 구조 (SwiftPM)
- [ ] `Package.swift` 작성 — `executableTarget`, platform `.macOS(.v14)`, Swift tools 6.x
- [ ] 소스 레이아웃 잡기
  - `Sources/TuneMouse/App/` — 앱 진입점, AppDelegate
  - `Sources/TuneMouse/MenuBar/` — 메뉴바 아이템
  - `Sources/TuneMouse/Settings/` — 설정 창 SwiftUI
  - `Sources/TuneMouse/Permissions/` — 접근성 권한 체크
  - `Sources/TuneMouse/Resources/` — 아이콘 등 (`Info.plist`은 번들 시 주입)
- [ ] `.gitignore` (`.build/`, `*.app`, `dist/` 등) — git init은 사용자 결정에 맡김

**수용 기준**: `swift build` 가 에러 없이 통과.

### 2. 앱 번들 / Info.plist
- [ ] `Info.plist` 작성
  - `CFBundleIdentifier = com.tunemouse.TuneMouse`
  - `LSUIElement = true` (Dock 아이콘 숨김, 메뉴바 전용)
  - `CFBundleName`, `CFBundleVersion`, `CFBundleShortVersionString`
  - `LSMinimumSystemVersion = 14.0`
- [ ] `.app` 번들 패키징 스크립트 — SwiftPM 산출물(맨 실행파일)을 `TuneMouse.app/Contents/{MacOS,Resources}` 구조로 조립 + Info.plist 주입

**수용 기준**: 생성된 `.app` 더블클릭으로 실행됨.

### 3. 메뉴바 앱 골격
- [ ] 앱 진입점 — `NSApplication` + `.accessory` activation policy (Dock 미표시)
- [ ] 메뉴바 아이템(`NSStatusItem`) + 아이콘(SF Symbol 임시)
- [ ] 메뉴 구성: **활성화 토글 / 설정 열기 / 종료**
- [ ] 활성화 토글 상태를 `UserDefaults`에 저장(아직 기능 연결은 안 함, 상태만)

> 결정 포인트: 메뉴바 구현은 **AppKit `NSStatusItem` + SwiftUI(설정창 호스팅)** 권장.
> SwiftUI `MenuBarExtra`(macOS 13+)가 더 간단하나, 확장성/제어를 위해 AppKit 상태아이템 권장.
> 시작은 둘 중 가벼운 쪽으로 가도 무방 — 마이그레이션 비용 낮음.

**수용 기준**: 메뉴바 아이콘 + 메뉴 동작, 종료됨.

### 4. 설정 창 (SwiftUI)
- [ ] 설정 윈도우 1개 (SwiftUI 뷰를 `NSWindow`/`NSHostingController`로 호스팅)
- [ ] 빈 골격 + "일반" 탭 자리만 (기능 UI는 후속 Phase)
- [ ] **접근성 권한 상태 섹션** 표시 (5번과 연결)

**수용 기준**: 메뉴 → 설정 열기로 창이 뜨고 닫힘.

### 5. 접근성 권한 플로우
- [ ] `AXIsProcessTrusted()` 로 권한 상태 확인
- [ ] 미허용 시 안내 + `AXIsProcessTrustedWithOptions(prompt:true)` 또는 시스템 설정 딥링크
  - 딥링크: `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`
- [ ] 권한 상태 폴링/갱신 (앱 포그라운드 복귀 시 재확인)
- [ ] (필요 판별) 입력 모니터링 권한도 동일 패턴으로 안내 — Phase 1에서 실제 탭 붙일 때 확정

**수용 기준**: 권한 허용 전/후 상태가 설정 창에 정확히 반영.

### 6. Self-signed 코드 서명
- [x] self-signed 코드서명 인증서 생성 ("TuneMouse Dev", 10년, 코드 서명) — 사용자 생성 완료
- [x] `build.sh`에 인증서 자동 탐지 + `codesign --force --sign` 통합 (가이드: [signing.md](signing.md))
- [x] self-signed 서명 적용 + seal 검증 (Authority=TuneMouse Dev, Designated Requirement 만족)
- [ ] 실제 권한 영속성 검증 — Phase 1에서 탭+권한 사용 시

> 메모: 인증서 생성은 GUI 작업이라 단계별 안내 문서를 따로 제공.
> ad-hoc 서명(`-`)으로도 동작은 하나 리빌드 시 권한 재요청 가능성 → self-signed 권장.

**수용 기준**: 리빌드 후에도 접근성 권한 유지.

### 7. 실행/디버그 워크플로우
- [x] `scripts/build.sh` — 빌드 + 번들 조립 + 서명 (인증서 자동 탐지)
- [x] `scripts/run.sh` — 기존 인스턴스 종료 후 `.app` 실행 (빠른 반복용)
- [x] 로그 토대 (`os.Logger`, `Support/Log.swift`) — Console.app / `log stream` 으로 확인, 실제 출력 검증됨
- [x] README에 개발 루프/요구사항 정리

**수용 기준**: `build.sh && run.sh` 로 변경→실행 반복 가능. ✅

### (추가) Phase 0 마무리 다듬기 — [phase-0-refinements.md](phase-0-refinements.md)
- [x] 로그인 시 자동 시작 (`SMAppService`) + 설정창 토글
- [x] 로깅 토대 (`os.Logger`)
- [x] README
- [x] 폴리시: 꺼짐 아이콘 흐리게 + tooltip, 메뉴 헤더 버전 표시
- [ ] (Phase 1로 이월) 패닉 키, 활성화 토글 실제 동작

---

## 실행 순서 (제안)
1 → 2 → 3 → 4 → 5 → 7 순으로 만들어 "실행되는 골격"을 먼저 띄우고,
6(서명)은 5(권한)까지 동작 확인 후 안정화 단계에서 적용.

## Phase 0 내 결정할 작은 것들
- 메뉴바 구현: `NSStatusItem`(권장) vs `MenuBarExtra` — 시작 시 확정
- 임시 메뉴바 아이콘: SF Symbol 사용 (전용 아이콘은 후속)

## 금지 구역 메모
- **배포/공증/릴리스 스크립트는 Phase 0 범위 아님** (프로덕션 단계). 그런 스크립트는 직접 수정 않고 제안만 → 사용자가 적용. (`build.sh`/`run.sh`는 로컬 개발 도구라 직접 작성 OK.)

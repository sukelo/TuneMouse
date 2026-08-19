# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 현황

TuneMouse는 Mac Mouse Fix 류의 macOS 마우스 향상 앱(메뉴바 앱)이다. **Phase 0~7 구현·검증 완료** — `Sources/TuneMouse/`에 32개 Swift 파일(약 1,600줄)로 세 축(스크롤 파이프라인/액션 매핑/앱별 오버라이드)이 모두 실동작한다. `SPEC.md`(협의 정리)가 설계 단일 진실 공급원이고, `docs/phase-N-*.md`가 단계별 작업/완료 기준 기록이다. 결정/계획을 바꾸면 해당 문서도 갱신한다.

언어는 협의/문서 모두 한국어다. 커밋 메시지도 한국어로 작성한다.

## 기술 스택 / 빌드

- Swift 6 + SwiftUI(설정창) + AppKit(`NSStatusItem` 메뉴바). 빌드는 **SwiftPM** (`Package.swift`, `executableTarget`, `.macOS(.v14)`). 타깃 arm64.
- **중요**: 이 머신은 **Xcode 미설치, CommandLineTools만** 있다. `xcodebuild`/Xcode 프로젝트 워크플로우를 가정하지 말 것. 빌드 검증은 `swift build`.
- 실행 파일은 SwiftPM 산출물을 `.app` 번들 구조(`TuneMouse.app/Contents/{MacOS,Resources}` + 주입된 Info.plist)로 수동 조립해야 동작한다. SwiftPM은 GUI 앱 번들을 자동 생성하지 않는다.
- 개발 루프: `scripts/build.sh`(빌드+번들 조립+self-signed 서명) → `scripts/run.sh`(기존 인스턴스 종료 후 `.app` 실행). 이 두 스크립트는 로컬 개발 도구이므로 직접 작성/수정해도 된다.

## 아키텍처 — 세 축(확장형)

설계 철학은 "처음부터 다 만들지 않고, 세 축을 확장형으로 깔아두고 쓰면서 하나씩 튜닝"이다. 새 기능은 이 세 축 중 하나에 끼워 넣는 형태로 설계한다.

1. **스크롤 변환 파이프라인**(`Pipeline/`, `Transformers/`) — 입력 휠 이벤트 → 변환 단계 체인(방향/스텝/듀레이션/부드러움/가속) → 출력. `Transformers/`에 Direction·Speed·Accel·SmoothScroll 4개 변환기가 플러그인처럼 끼워지며, on/off + 파라미터(튜닝 가능)를 가진다.
2. **액션 매핑 엔진**(`Actions/`) — 트리거(버튼/클릭/홀드/드래그 + modifier) → 액션(단축키 발사/내비게이션/미션컨트롤 등). `KeystrokeEngine` 하나로 대부분 커버, 액션 종류는 확장형.
3. **앱별 오버라이드 레이어**(`Pipeline/AppContextProvider.swift`, `Settings/AppScrollOverrideView.swift`) — bundle id로 규칙 resolve. 모드: 수정 / 통과(예외) / 커스텀. 위 두 축 모두 이 레이어로 앱별 조정 가능.
   - **주의**: 이벤트 타입별로 resolve 기준이 다르다. 스크롤은 **커서 아래 창의 앱**(macOS가 휠 이벤트를 커서 위치로 라우팅하기 때문, `docs/phase-7-scroll-cursor-target.md` 참고), 버튼은 frontmost 앱(`NSWorkspace`) 기준. 새 축을 앱별 오버라이드에 연결할 땐 어느 기준이 맞는지 먼저 판단할 것.

설정 데이터 모델은 **글로벌 기본 + 앱별 override** 구조로 짜여 있다(`Settings/ScrollSettings.swift`, `Actions/ButtonMappingStore.swift`; 나중에 멀티 마우스 프로필도 같은 패턴으로 확장 가능). 저장은 `UserDefaults`(추후 JSON 가져오기/내보내기 예정).

이벤트 처리는 `EventTap/EventTapController.swift`가 CoreGraphics `CGEvent` Tap으로 전역 마우스 이벤트를 가로채 `Pipeline/EventPipeline.swift`에서 가공 후 재전송한다.

## 변경 불가 제약 (위반 금지)

- **트랙패드 이벤트는 절대 건드리지 않는다.** 마우스 휠/버튼만 가공, 트랙패드 제스처는 OS 기본 통과.
- **접근성(Accessibility) 권한 필수** — `AXIsProcessTrusted()`로 확인, 미허용 시 안내 UI + 시스템 설정 딥링크(`x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`).
- **App Store 배포 불가** — 전역 이벤트 탭은 샌드박스에서 차단. 직접 배포(공증 DMG)가 전제.
- **권한이 코드 서명 정체성에 묶인다** — 개인용 단계는 안정적 self-signed 인증서로 서명해 리빌드 시 권한 재허용을 막는다. ad-hoc(`-`) 서명은 리빌드마다 권한 재요청 위험.
- 메뉴바 전용 앱: `LSUIElement = true`, `.accessory` activation policy(Dock 미표시). Bundle ID `com.tunemouse.TuneMouse`.

## 안전 설계 (필수 동작)

- 이벤트 탭이 느리면 macOS가 자동 비활성화 → **재활성화 로직** 필요.
- **패닉 키**(전역 토글 단축키) + 메뉴바 토글로 언제든 전체 기능을 즉시 끌 수 있어야 한다.

## 구현 순서 (전 단계 완료)

Phase 0(셋업: 실행되는 메뉴바 골격 + 권한 플로우 + 빌드 스크립트) → Phase 1(이벤트 탭 인프라) → Phase 2(스크롤 방향/속도) → Phase 3(버튼 리매핑) → Phase 4(부드러운 스크롤) → Phase 5(앱별 스크롤 오버라이드) → Phase 6(앱별 개별값 편집 UI) → Phase 7(스크롤 오버라이드 판단 기준을 frontmost → 커서 아래 앱으로 수정). 기능 우선순위는 버튼 리매핑이 1순위였지만, **탭 동작을 빠르게 검증하기 위해 스크롤 방향/속도(Phase 2)를 먼저** 구현하는 순서를 택했다. 각 단계 세부는 `docs/phase-N-*.md` 참고. 다음 단계를 시작할 때는 이 목록에 이어서 Phase 8부터 문서를 추가한다.

## 금지 구역

배포/공증/릴리스 스크립트, `.env` 류 환경 파일은 직접 수정하지 않는다 — 변경안을 제안하고 사용자가 적용한다. (`build.sh`/`run.sh`는 로컬 개발 도구라 예외.)

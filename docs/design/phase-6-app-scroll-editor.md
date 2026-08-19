# Phase 6 — 앱별 스크롤 개별값 편집 UI 작업 파일

> **작업 당시의 설계 노트입니다.** 체크박스와 완료 기준은 그 시점의 작업 목록이며,
> 현재 구현 상태를 나타내지 않습니다. 최신 상태는 [README](../../README.md)를 보세요.

> 목표: **Phase 5에서 deferred했던 "앱별 방향/속도/가속제거/부드러움 개별값 편집"을 UI로 노출.**
> 엔진(`resolved(forBundleID:)`)·데이터 모델은 이미 앱별을 완전 지원 — **순수 UI 작업**이다.
> 관련: [SPEC.md](../../SPEC.md), 이전: [phase-5-app-scroll-override.md](phase-5-app-scroll-override.md)

## 배경

- 현재 앱별 스크롤 UI([AppScrollOverrideView.swift](../../Sources/TuneMouse/Settings/AppScrollOverrideView.swift))는 오버라이드 추가 시 `ScrollConfig()` + `passthrough = true`만 세팅 → 실질적으로 **"통과(예외)" 하나만** 노출.
- 엔진은 앱별 방향/속도/가속제거/부드러움을 이미 다 해석(각 변환기 `isEnabled`가 `perApp.values`까지 검사). **UI만 비어 있음.**
- `resolved`는 **교체 semantics**(앱 오버라이드가 있으면 글로벌 통째 대체, 필드 병합 아님). 이번 단계도 **교체 유지** — 병합 모드는 별건.

## 핵심 결정 — 새 오버라이드는 "전역 복사"로 시작

교체 모델이라 시작값이 곧 동작이다. 새 앱 오버라이드 추가 시:

> **`var config = store.settings.global` 스냅샷으로 시작** (`ScrollConfig()` 기본값 아님).

- 멘탈 모델: **"전역과 똑같이 두고, 다른 것만 수정"** — 흔한 패턴에 맞음.
- 추가 직후 그 앱의 스크롤 느낌이 전역과 동일 → "왜 이 앱만 갑자기 기본값?" 혼란 없음.
- 순수 통과 용도는 그 안에서 통과 토글만 켜면 됨(시작값과 무관).
- 감수할 특성: 전역을 나중에 바꿔도 **이미 만든 앱 복사본엔 반영 안 됨**(교체 모델의 본질).

## Definition of Done

- [x] 앱별 항목을 펼쳐 **방향 반전 / 속도 / 가속제거+노치당거리 / 부드러움+스텝+부드러움** 을 개별 편집 가능.
- [x] "통과(스크롤 가공 끄기)" 토글은 그 안의 한 옵션 — 켜면 나머지 컨트롤 비활성.
- [x] 새 오버라이드 추가 시 **전역값을 복사**해 시작.
- [x] 전역 섹션과 앱별 섹션이 **동일 편집 UI를 공유**(기능 패리티 자동 보장).
- [ ] 즉시 반영·영속화. 글로벌/기존 앱별 저장본 회귀 없음, 트랙패드 무영향. *(체감 검증 필요)*

## 작업 항목

### 1. 편집 뷰 추출 — `ScrollConfigEditor`
- [x] 전역 컨트롤을 재사용 뷰([ScrollConfigEditor.swift](../../Sources/TuneMouse/Settings/ScrollConfigEditor.swift))로 분리.
  ```swift
  struct ScrollConfigEditor: View {
      @Binding var config: ScrollConfig
      var includePassthrough: Bool   // 전역=false, 앱별=true
  }
  ```
- [x] 컨트롤: 세로/가로 반전, 속도 슬라이더, 가속제거 토글(+노치당거리 슬라이더 조건부), 부드러움 토글(+스텝·부드러움 슬라이더 조건부).
- [x] `includePassthrough`면 맨 위 "스크롤 가공 끄기(통과)" 토글, 켜지면 나머지 `.disabled(config.passthrough)`.

**수용 기준**: 한 뷰로 전역·앱별 모두 편집. 한쪽만 기능이 빠지는 불일치 불가능.

### 2. 전역 섹션 교체
- [x] `scrollSection` → `ScrollConfigEditor(config: $scrollSettings.settings.global)`.
- [x] "기본값으로" 버튼 유지.

### 3. 앱별 섹션 재작성 ([AppScrollOverrideView.swift](../../Sources/TuneMouse/Settings/AppScrollOverrideView.swift))
- [x] 각 앱 항목을 `DisclosureGroup`으로:
  - 헤더: 앱 이름 + 상태 요약(예: `통과` / `속도 2×` / `반전·부드러움`) + 삭제 버튼.
  - 펼침: `ScrollConfigEditor(config: configBinding(id), includePassthrough: true)`.
- [x] `configBinding(id) -> Binding<ScrollConfig>`: 기존 `passthroughBinding`을 config 전체 read/write로 일반화.
- [x] `add()`: `store.settings.perApp[bundleID] = store.settings.global`(전역 복사). `passthrough = true` 강제 제거.
- [x] 섹션 제목 **"앱별 스크롤 예외" → "앱별 스크롤 설정"**.

**수용 기준**: 앱 추가 → 펼쳐 속도만 2배 → 그 앱만 2배, 다른 앱은 전역값.

### 4. 검증
- [ ] 전역 부드러움 ON 상태에서 특정 앱만 속도 0.5×로 → 그 앱만 느림, 부드러움은 유지(전역 복사 확인).
- [ ] 통과 토글 켜면 그 앱 원본 스크롤.
- [ ] 기존 저장본(통과=ON, 나머지 기본)이 통과 켜진 상태로 정상 표시(마이그레이션 불필요 — `ScrollConfig` 형태 불변).
- [ ] 글로벌 동작 회귀 없음, 트랙패드 무영향.

## 손대지 않음 (이미 준비됨)
- 엔진/해석 `resolved(forBundleID:)` — 교체 모델 유지.
- 각 변환기 `isEnabled` — 이미 `perApp.values` 검사 → 앱별 값만 켜도 활성화. 배선 추가 불필요.
- `ScrollSettings`/`ScrollSettingsStore` — `perApp` 통째 직렬화 그대로.

## 파일 레이아웃
```
Sources/TuneMouse/Settings/SettingsView.swift            # ScrollConfigEditor 추출 + 전역 섹션 교체
Sources/TuneMouse/Settings/AppScrollOverrideView.swift   # DisclosureGroup 편집 UI, add는 전역복사
# ScrollSettings.swift / 변환기 / AppDelegate — 변경 없음
```

## 실행 순서
1(편집 뷰 추출) → 2(전역 교체로 동등성 확인) → 3(앱별 재작성) → 4(검증).


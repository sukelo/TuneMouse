# Phase 5 — 앱별 스크롤 오버라이드 작업 파일

> **작업 당시의 설계 노트입니다.** 체크박스와 완료 기준은 그 시점의 작업 목록이며,
> 현재 구현 상태를 나타내지 않습니다. 최신 상태는 [README](../../README.md)를 보세요.

> 목표: **축3(앱별 오버라이드)을 스크롤까지 완성.** 핵심은 **"통과(예외)" 모드** — 특정 앱에서 스크롤 가공을 끈다.
> 백로그 직결: **아이폰 미러링 스크롤 이상**, **게임 예외**.
> 관련: [SPEC.md](../../SPEC.md), 이전: [phase-4-smooth-scroll.md](phase-4-smooth-scroll.md)

## 배경

- 데이터 모델은 이미 글로벌+앱별(`ScrollSettings.resolved(forBundleID:)`, Phase 2). 앱 오버라이드가 글로벌을 **대체**.
- 현재 스크롤 변환기 중 **smooth만** 앱별 해석. **direction/speed는 글로벌 전용**, **앱별 스크롤 UI 없음** → 이걸 채운다.
- resolved가 글로벌을 대체하므로, **중립값 앱 오버라이드 = 사실상 통과**. 명시적 `passthrough` 플래그로 UX를 분명히 한다.

## Definition of Done

- [ ] **앱별 "스크롤 가공 끄기(통과)"** — 지정 앱에서 방향/속도/부드러움 모두 미적용.
- [ ] **아이폰 미러링**에서 통과로 스크롤 정상화.
- [ ] direction/speed/smooth가 **모두 앱별 해석**으로 통일(글로벌은 기본값).
- [ ] 설정 UI로 앱별 오버라이드 **추가/토글/삭제**.
- [ ] 영속화/즉시 반영. 글로벌 동작 회귀 없음.

## 작업 항목

### 1. ScrollConfig에 passthrough
- [ ] `var passthrough = false` 추가(구버전 저장본 호환 decode).

### 2. 스크롤 변환기 앱별 통일
- [ ] `ScrollDirectionTransformer`/`ScrollSpeedTransformer`도 `var settings` 보유 + `resolved(forBundleID:)` 사용(smooth와 동일 패턴).
- [ ] 각 변환기: 해석된 config가 `passthrough`면 `.passUnchanged`(가공 skip).
- [ ] `AppDelegate.applyScrollSettings`: 세 변환기에 `.settings = settings` 전달(글로벌 파라미터 직접 세팅 제거).
- [ ] isEnabled: 글로벌 또는 임의 앱별 설정이 효과를 줄 수 있으면 true.

**수용 기준**: 같은 휠이 앱에 따라 다르게(또는 통과로) 동작.

### 3. 앱별 오버라이드 UI
- [ ] 스크롤 섹션에 "앱별 예외" 목록: 실행 중 앱 선택 → 오버라이드 추가.
- [ ] 각 항목: 앱 이름 + **"스크롤 가공 끄기"** 토글 + 삭제.
- [ ] (확장) 앱별 방향/속도/부드러움 개별 값 편집은 후속 — 엔진은 이미 지원.

**수용 기준**: UI로 앱별 통과를 켜고 즉시 반영.

### 4. 검증
- [ ] 글로벌 부드러움/반전 켠 상태에서 특정 앱 통과 → 그 앱만 원본 스크롤.
- [ ] 아이폰 미러링 통과로 스크롤 정상.
- [ ] 글로벌 동작 회귀 없음, 트랙패드 무영향.

## 결정 / 주의
- **통과 의미**: 해석된 config.passthrough면 모든 스크롤 변환기 skip. (글로벌엔 보통 passthrough 안 씀 — 앱별 예외용.)
- **resolved 대체 semantics 유지**: 앱 오버라이드는 글로벌 대체. (병합 모드는 후속.)
- speed 변환기 누적 잔차는 앱 전환 시 공유(미세 artifact 허용).

## 파일 레이아웃
```
Sources/TuneMouse/Settings/ScrollSettings.swift            # passthrough 추가(기존)
Sources/TuneMouse/Transformers/ScrollDirectionTransformer.swift  # 앱별 해석(기존)
Sources/TuneMouse/Transformers/ScrollSpeedTransformer.swift      # 앱별 해석(기존)
Sources/TuneMouse/Settings/SettingsView.swift / 신규 뷰         # 앱별 예외 UI
```

## 실행 순서
1(passthrough) → 2(변환기 통일) → 통과/앱별 검증(시드) → 3(UI) → 4 최종 검증.

## 후속 — 메뉴바 빠른 통과 토글

데일리 마찰 제거: 설정창을 열지 않고 메뉴바에서 현재 앱의 통과를 켜고 끈다(아이폰 미러링/게임 예외 = 클릭 한 번).
- `StatusItemController`에 `현재 앱: <이름>` 라벨 + `이 앱에서 스크롤 끄기` 체크 토글. `menuWillOpen`에서 `NSWorkspace.frontmostApplication`로 갱신(상태 메뉴는 accessory 앱을 활성화하지 않아 실제 앞 앱 유지). 우리 앱/미식별 앱은 비활성.
- 토글은 `scrollSettings.perApp[id].passthrough`를 뒤집음. 새 항목은 전역 복사 기반(Phase 6 모델), 해제로 전역과 같아지면 항목 자동 제거. 변경은 `@Published`로 변환기에 즉시 반영.


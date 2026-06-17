# Phase 2 — 스크롤 방향/속도 작업 파일

> 목표: **첫 실제 기능** — 마우스 휠 스크롤의 **방향 반전 + 속도/스텝 배율**.
> 동시에 Phase 1 점검에서 이월된 **파이프라인 구조(F7)** 와 **처리 컨텍스트(F8)** 를 여기서 깐다.
> 부드러운 스크롤(관성/듀레이션)은 **Phase 4** — 여기서는 휠 이벤트의 delta를 즉시 변형하는 무상태 변환만.
> 관련: [SPEC.md](../SPEC.md), 이전: [phase-1-event-tap.md](phase-1-event-tap.md)

## Definition of Done (완료 기준)

- [x] **방향 반전** 토글로 휠 위/아래(및 가로)가 반대로 동작한다. *(체감 확인: 아래→위)*
- [x] **속도/스텝 배율**로 스크롤이 느리게/빠르게 조절된다. *(슬라이더 체감 확인)*
- [x] 기능 off 또는 기본값(반전 off·배율 1.0)일 때 **완전 통과**(무변화). *(라이브 토글 off 시 정상 복귀)*
- [x] **트랙패드는 전혀 영향 없음**(연속 스크롤은 이미 Phase 1에서 필터).
- [x] 설정이 `UserDefaults`에 저장되고 **재시작해도 유지**된다. *(JSON 저장 확인)*
- [x] 설정 변경이 **즉시 반영**된다(재실행 불필요). *(라이브 UI 토글 반영 확인)*
- [x] 처리 구조가 **파이프라인(순서 있는 변환기 체인)** 으로 바뀐다(F7).
- [x] **ProcessingContext** 가 도입되어 변환기에 전달된다(F8, 앱별 오버라이드 토대).

---

## 작업 항목

### 1. 파이프라인 구조 (F7)
- [ ] `EventTransformer` 프로토콜: `transform(event:type:context:) -> ProcessResult`
- [ ] `EventPipeline`(= `EventProcessor` 구현): 활성 변환기를 **순서대로** 통과. 각 변환기 on/off + 파라미터 보유.
- [ ] `EventTapController` 는 단일 processor 대신 이 파이프라인을 받음(변경 최소).

**수용 기준**: 변환기 0개면 통과. 여러 개면 순서대로 적용.

### 2. 처리 컨텍스트 (F8) + frontmost 앱 캐싱
- [ ] `ProcessingContext`: 최소한 frontmost 앱 bundle id 제공(확장 가능 struct).
- [ ] `AppContextProvider`: **per-event 조회 금지** — `NSWorkspace.didActivateApplicationNotification` 로 frontmost bundle id를 캐싱.
- [ ] Phase 2 스크롤 변환기는 아직 bundle id를 안 써도 됨(앱 오버라이드는 후속). **시그니처/토대만** 깐다.

**수용 기준**: 컨텍스트가 변환기에 전달됨. 앱 전환 시 캐시 갱신(per-event 비용 0).

### 3. 스크롤 방향 반전 변환기
- [ ] 세로(axis1) / 가로(axis2) 반전 토글
- [ ] **CGEvent 스크롤 필드 일관 수정**: `scrollWheelEventDeltaAxis1/2`, `…PointDeltaAxis1/2`, `…FixedPtDeltaAxis1/2` 를 함께 부호 반전(일부만 바꾸면 앱별로 이상 동작)
- [ ] 휠(비연속)만 대상 — 트랙패드는 이미 제외됨

**수용 기준**: 토글 시 휠 방향 반대. 끄면 원복.

### 4. 스크롤 속도/스텝 배율 변환기
- [ ] 배율(double, 기본 1.0)로 delta 크기 스케일 — 위 세 delta 필드 일관 적용
- [ ] 정수 라인 delta는 반올림/누적 처리(작은 배율에서 0 되지 않게 누적 잔차 고려)
- [ ] (선택) "스텝"(노치당 라인 수) 개념을 배율로 흡수

**수용 기준**: 배율↑ 빠르게, ↓ 느리게. 1.0이면 무변화.

### 5. 스크롤 설정 데이터 모델 + 영속화
- [ ] `ScrollSettings`: invertVertical/Horizontal(bool), speedMultiplier(double) 등
- [ ] **구조는 "글로벌 기본 + 앱별 override"** 로 설계(앱별 UI는 후속, 데이터 모델만 확장형). SPEC의 데이터 모델 원칙.
- [ ] `UserDefaults` 저장/로드 (Codable + JSON 또는 키별 저장)

**수용 기준**: 값 변경 후 재시작에도 유지.

### 6. 설정 UI (스크롤 섹션)
- [ ] 설정창에 "스크롤" 섹션: 방향 반전 토글(세로/가로), 속도 슬라이더
- [ ] 현재 값 표시, 기본값 복원(선택)

**수용 기준**: UI로 조절 가능, 직관적.

### 7. 설정 ↔ 파이프라인 연결 (라이브 반영)
- [ ] 설정 변경 → 변환기 파라미터 갱신(메인에서, 콜백과 동일 스레드라 안전)
- [ ] 변환기 on/off 도 설정에 연동

**수용 기준**: 슬라이더 움직이면 즉시 스크롤 동작 변화.

### 8. 검증
- [ ] `debugEventLogging` 로 delta 변형 전/후 로그 확인
- [ ] 실제 스크롤로 방향/속도 체감
- [ ] **트랙패드 두 손가락 스크롤 무영향** 재확인
- [ ] 기능 off 시 완전 통과

---

## 아키텍처 결정 (구현 시 확정)

- **스크롤 delta 필드 일관성**: line/point/fixedPt 세 종류를 함께 변형. 앱마다 읽는 필드가 달라 일부만 바꾸면 회귀.
- **frontmost 앱**: per-event `NSWorkspace.frontmostApplication` 조회는 비쌈 → 알림 기반 캐싱.
- **변환기 실행 스레드**: 현재 메인 런루프(Phase 1 그대로). 설정값은 메인에서만 변경 → 락 불필요. (Phase 4에서 전용 스레드 이전 시 재검토 — F6.)
- **누적 잔차**: 분수 배율로 정수 라인 delta가 0이 되는 문제 → 변환기 내부에 누적 잔차(accumulator) 유지 검토.

## 파일 레이아웃(안)
```
Sources/TuneMouse/Pipeline/EventTransformer.swift       # 변환기 프로토콜 + ProcessingContext
Sources/TuneMouse/Pipeline/EventPipeline.swift          # 순서 있는 체인 (EventProcessor 구현)
Sources/TuneMouse/Pipeline/AppContextProvider.swift     # frontmost bundle id 캐싱
Sources/TuneMouse/Transformers/ScrollDirectionTransformer.swift
Sources/TuneMouse/Transformers/ScrollSpeedTransformer.swift
Sources/TuneMouse/Settings/ScrollSettings.swift         # 글로벌+오버라이드 모델 + 영속화
Sources/TuneMouse/Settings/SettingsView.swift           # 스크롤 섹션 추가(기존 파일)
```

## 실행 순서(제안)
1(파이프라인) → 2(컨텍스트) 로 토대 교체 후 통과 확인 →
3(방향 반전) 먼저(체감 즉시·검증 쉬움) → 5·6·7(설정/UI/연결) → 4(속도 배율) → 8(검증).

## 위험 / 주의
- **delta 필드 부분 수정**으로 인한 앱별 회귀 → 세 필드 일관 처리로 방어.
- **트랙패드 회귀 절대 금지** — 변환기 진입 전 연속 스크롤 필터 유지(이미 Phase 1).
- 분수 배율의 0-delta 문제 → 누적 잔차.
- 가로 스크롤(Shift+휠)·자연스러운 스크롤 설정과의 상호작용 확인.

## 검증 방법
- `defaults write com.tunemouse.TuneMouse debugEventLogging -bool true` → delta 전/후 로그.
- 방향 반전 on/off, 배율 0.5/2.0 등으로 실제 스크롤 체감.
- 트랙패드 스크롤이 변형 로그에 안 잡히는지.

## 점검 후 처리 (Phase 2 리뷰)

처리:
- **P2-2 [수정]** 속도 변환기 residual을 **스크롤 방향 전환 시 리셋** — 반대 방향 잔차가 첫 틱을 먹는 문제 방지.
- **P2-6 [수정]** 설정창을 `ScrollView`로 감쌈 — 권한 미허용 시 섹션이 길어져 잘리는 것 방지.

이월/기록:
- **P2-1** Shift+휠 가로 스크롤(axis1+modifier)은 현재 가로 반전(axis2) 대상 아님 → 나중에 추가(가산형이라 무방).
- **P2-4** 앱별 오버라이드 경로(`resolved(forBundleID:)`)는 UI/배선 전까지 미사용(의도된 deferred, Phase 3+).
- **P2-5** 변환기 목록 하드코딩 → 많아지면 레지스트리.
- **P2-7** 속도 슬라이더 1.0 디텐트 없음(사소).
- 동시성: 변환기 상태는 메인 단일 접근으로 안전, 전용 스레드 이전 시 재검토(F6).

## 후속 추가 — 스크롤 가속 제거(선형)

macOS는 휠 입력 속도에 따라 픽셀 delta를 지수적으로 키우는 **가속 곡선**을 적용한다(빨리 굴릴수록 노치당 거리↑). 윈도우식 **노치당 고정 거리(리니어)** 가 필요해 별도 모드로 추가.

- **데이터**: `ScrollConfig.linearScroll`(Bool) + `pixelsPerNotch`(Double, 기본 40). Codable 마이그레이션(decodeIfPresent)으로 구버전 저장본 호환.
- **변환기**: `ScrollAccelTransformer`. 라인 delta(노치 카운트)가 있을 때만 동작 → 픽셀 delta(`PointDelta`/`FixedPtDelta`)를 OS 가속값 버리고 고정 거리로 덮어씀.
- **라인 delta도 정규화(개정)**: macOS는 라인 delta에도 가속을 걸어(빨리 굴리면 1노치가 2~3라인) "10노치=고정"이 깨졌다. 이벤트 1개를 1노치로 보고 **라인 delta를 ±1로, 픽셀을 ±pixelsPerNotch로** 덮어써 속도 무관 균일을 보장. (라인 delta를 읽는 앱·하류 부드러운 스크롤에도 균일 적용.) 노치당 이벤트 1개인 휠 마우스 전제 — 자유회전 휠에서 다중라인 단일 이벤트면 과소 스크롤 가능(추후 재검토).
- **체인 순서**: 방향 → **선형화** → 속도 배율 → 부드러움. 부드러운 스크롤이 켜지면 그쪽이 라인 delta만 보고 픽셀을 재구성하므로 선형화는 자연히 무시됨(충돌 없음).
- **앱별**: `resolved(forBundleID:)`로 글로벌/앱별 모두 적용 가능(엔진 지원). 앱별 개별값 편집 UI는 후속 — 현재 글로벌 UI만 노출.
- **연속/모멘텀**: 라인 delta가 없는 스트림은 미변형(트랙패드는 이미 탭 진입 전 필터).

## 금지 구역 메모
- 배포/공증 스크립트는 손대지 않음. `build.sh`/`run.sh`만 로컬 도구로 갱신 가능.

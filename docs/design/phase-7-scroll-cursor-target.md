# Phase 7 — 스크롤 오버라이드를 "커서 아래 앱" 기준으로 (버그픽스)

> **작업 당시의 설계 노트입니다.** 체크박스와 완료 기준은 그 시점의 작업 목록이며,
> 현재 구현 상태를 나타내지 않습니다. 최신 상태는 [README](../../README.md)를 보세요.

> 목표: 앱별 스크롤 오버라이드가 **포커스(frontmost) 앱**이 아니라 **커서 아래 창의 앱**으로 resolve되게 한다.
> 증상: 특정 앱(예: cmux) override가 **적용됐다 안 됐다** 함.
> 관련: [SPEC.md](../../SPEC.md), [phase-5-app-scroll-override.md](phase-5-app-scroll-override.md), [phase-6-app-scroll-editor.md](phase-6-app-scroll-editor.md)

## 배경 / 증상

`com.cmuxterm.app`에 스크롤 override를 걸었는데, 같은 앱에서 스크롤이 글로벌로 갔다 override로 갔다 한다.

## 근본 원인

- macOS는 **휠 스크롤 이벤트를 "커서 아래 창"으로 라우팅**한다(포커스/키 윈도우와 무관 — 비활성 배경 창도 커서 아래면 스크롤됨).
- 그런데 TuneMouse는 override를 `AppContextProvider.currentBundleID` = `NSWorkspace.frontmostApplication`(**포커스 가진 활성 앱**)으로 resolve한다.
- 둘이 다를 수 있다:
  - cmux가 포커스 && 커서 아래 → `frontmost == com.cmuxterm.app` → cmux override ✅
  - 다른 앱이 포커스, cmux엔 **호버만** → `frontmost == 다른 앱` → 글로벌 적용 ❌
- 즉 **스크롤 라우팅 기준(커서)** 과 **override 판단 기준(포커스)** 이 어긋나 "왔다갔다"가 발생.

`ScrollSettings.resolved(forBundleID:)` 로직 자체는 정상. 넘기는 bundleID가 틀린 것.

## Definition of Done

- [x] 스크롤 override가 **커서 아래 창의 앱**으로 resolve된다(포커스 무관).
- [x] cmux에 호버만 하고 스크롤해도 cmux override가 **일관 적용**.
- [x] 커서 아래 창을 못 찾으면(바탕화면 등) 합리적 폴백(글로벌).
- [x] 핫패스 성능 회귀 없음(스크롤 버스트 중 창 조회 캐싱).
- [x] 트랙패드/연속 스크롤 무영향, 글로벌 동작 회귀 없음.
- [x] 추가 권한(화면 기록) 불필요 — bounds/PID/layer만 사용.

> 구현 완료(2026-06-18). 커서 호버-스크롤에서 앱 override 일관 적용 확인.

## 기술 접근

### 커서 아래 앱 판별
1. 스크롤 이벤트에서 커서 좌표: `event.location` (CG 전역 좌표, **좌상단 원점**).
2. `CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)` — **앞→뒤 순서**로 온스크린 창 목록. 각 창에서:
   - `kCGWindowBounds`(CG 좌표, 좌상단 원점 — `event.location`과 동일계라 직접 hit-test 가능)
   - `kCGWindowOwnerPID`, `kCGWindowLayer`
3. 조건을 만족하는 **첫(=최상단)** 창 선택:
   - `layer == 0` (일반 창. 메뉴바/Dock/오버레이 등 비-0 레이어 제외)
   - bounds가 커서 좌표 포함
   - owner PID ≠ TuneMouse 자신(우리 설정창/오버레이 무시)
4. 그 창의 `ownerPID` → `NSRunningApplication(processIdentifier:)?.bundleIdentifier`.
5. 못 찾으면 `nil` → `resolved`가 글로벌로 폴백.

> 권한 메모: 창 **이름**(kCGWindowName)은 화면 기록 권한이 필요하지만, 우리는 **bounds/PID/layer만** 읽으므로 접근성 권한만으로 충분. 화면 기록 권한 요구하지 않게 kCGWindowName 접근 금지.

### 캐싱(핫패스)
- 창 목록 조회는 매 이벤트마다 하면 비싸다. 스크롤 버스트 중엔 커서가 거의 고정 → **단기 캐시**:
  - 키: 정수 반올림한 커서 좌표(또는 직전 좌표와의 근접 판정).
  - TTL: 짧게(예: ~150–250ms). 좌표가 바뀌거나 TTL 만료 시 재조회.
  - `Date.now` 대신 핫패스에선 `CACurrentMediaTime()`/단조 시계 사용.
- **PID → bundleID 캐시**(PID는 앱 생존 동안 안정). 앱 종료/재실행 대비 가벼운 무효화는 후속.

### 파이프라인 배선
- `ProcessingContext`가 지금 `frontmostBundleID` 하나만 들고 있다. 스크롤은 커서-앱, 버튼은 포커스-앱이 자연스러우므로 **이벤트 타입별로 적절한 대상**을 채운다.
  - 권장: 필드명을 `targetBundleID`로 일반화하고, `EventPipeline.process`에서
    - `.scrollWheel` → `contextProvider.bundleID(atScreenPoint: event.location)`
    - 그 외(버튼) → `contextProvider.currentBundleID`(frontmost)
    로 채운다. 변환기는 읽는 필드만 바뀜(로직 동일).
  - 대안: `frontmostBundleID` 유지 + `scrollTargetBundleID` 추가(스크롤 변환기만 후자 사용). 변경 범위 최소지만 필드 2개.
- 버튼 매핑은 클릭=활성화라 frontmost로도 대체로 맞음. **이번 변경 범위는 스크롤 우선**, 버튼 통일은 선택(아래 "결정" 참고).

## 작업 항목

### 1. AppContextProvider에 커서-앱 조회
- [ ] `func bundleID(atScreenPoint point: CGPoint) -> String?` 추가.
- [ ] CGWindowList hit-test + layer/owner 필터 + 자기 PID 제외.
- [ ] PID→bundleID 캐시, 좌표 기반 단기 캐시.
- [ ] 자기 PID는 `ProcessInfo.processInfo.processIdentifier`로 1회 확보.

### 2. ProcessingContext / 파이프라인
- [ ] `ProcessingContext` 필드 일반화(`targetBundleID`) 또는 `scrollTargetBundleID` 추가.
- [ ] `EventPipeline.process`: 이벤트 타입별로 대상 bundleID 채움.
- [ ] 스크롤 변환기 4종(direction/accel/speed/smooth)이 새 필드로 resolve.

### 3. 검증
- [ ] cmux 포커스 X + 호버 스크롤 → cmux override 일관 적용.
- [ ] 포커스/비포커스 전환하며 스크롤해도 동일 결과.
- [ ] 바탕화면/창 없는 곳 스크롤 → 글로벌 폴백, 크래시 없음.
- [ ] 빠른 플링 스크롤에서 끊김/지연 없음(캐시 효과).
- [ ] 트랙패드 무영향, 글로벌 동작 회귀 없음.
- [ ] 화면 기록 권한 프롬프트가 뜨지 않음.

## 결정 / 주의

- **좌표계**: `event.location`과 `kCGWindowBounds` 모두 CG 좌상단 원점 → 변환 없이 hit-test. (NSScreen 하단 원점과 혼용 금지.)
- **레이어 필터**: `layer == 0`만. 단, 일부 앱 메인 창이 비-0일 가능성 대비해 검증 중 로깅으로 확인. 과도 필터로 정상 창을 놓치지 않게.
- **폴백**: 대상 못 찾으면 `nil` → 글로벌. (포커스 앱으로 폴백할지 여부는 선택 — 일단 글로벌이 단순/예측가능.)
- **버튼 범위**: 이번엔 스크롤만 커서-기준. 버튼까지 커서-기준 통일은 별도 결정(드래그 등은 버튼 down 시점 앱이 적절할 수 있어 신중).
- **성능**: 캐시 없이 매 이벤트 CGWindowList 조회는 금지. 단기 캐시 필수.
- **트랙패드**: 기존 `isContinuousScroll` 통과 분기는 그대로 — 커서-앱 조회 이전 단계에서 걸러짐.

## 파일 레이아웃
```
Sources/TuneMouse/Pipeline/AppContextProvider.swift   # bundleID(atScreenPoint:) + 캐시 (기존)
Sources/TuneMouse/Pipeline/EventTransformer.swift      # ProcessingContext 필드 (기존)
Sources/TuneMouse/Pipeline/EventPipeline.swift         # 타입별 대상 bundleID 주입 (기존)
Sources/TuneMouse/Transformers/Scroll*Transformer.swift # 새 필드로 resolve (기존)
```

## 실행 순서
1(커서-앱 조회 + 캐시) → 2(파이프라인 배선) → 시드 값으로 호버 스크롤 검증 → 3 최종 검증.


# Phase 1 — 이벤트 탭 인프라 작업 파일

> 목표: **전역 마우스 이벤트를 가로채 → (지금은 통과) 처리 → 재전송하는 토대**를 만든다.
> 세 축(스크롤 파이프라인 / 액션 엔진 / 앱별 오버라이드)이 끼워질 **자리(seam)** 를 깔되,
> Phase 1에서는 실제 가공 없이 **통과(pass-through)** 만 한다. 탭이 제대로 도는지 검증이 핵심.
> 관련 결정사항: [SPEC.md](../SPEC.md), 이전 단계: [phase-0-setup.md](phase-0-setup.md)

## Definition of Done (완료 기준)

- [x] 접근성 권한 + 활성화 토글이 켜지면 `CGEventTap` 이 설치되고, 꺼지면 해제된다. *(로그로 install/uninstall 확인)*
- [x] 탭 설치 후에도 **마우스가 평소처럼 정상 동작**한다(통과 단계라 체감 변화 없음). *(테스트 중 정상)*
- [x] **트랙패드 스크롤/제스처는 절대 건드리지 않는다** — 가공 대상에서 제외(통과). *(연속 스크롤은 처리기 도달 전 필터, 관측된 마우스 스크롤은 모두 continuous=0)*
- [x] 마우스 휠/버튼 이벤트가 콜백에 들어오는 것을 **로그로 확인**할 수 있다. *(scroll + buttonDown #0/#3/#4(type=25) 확인 — 옆버튼=Safari 뒤로가기 토대)*
- [x] 탭이 느려서 OS가 비활성화하면(`.tapDisabledByTimeout`) **자동 재활성화**된다. *(로직 구현 완료. 강제 타임아웃 트리거는 미검증)*
- [x] **패닉 키**(전역 단축키)로 전체 기능을 즉시 on/off 할 수 있다. *(⌃⌥⌘M 토글 확인)*
- [x] 권한 없을 때 탭 생성 실패를 **안전하게 처리**하고 UI에 반영한다(크래시·먹통 없음). *(권한 미허용 시 안전 보류 확인)*

> 부수 검증: self-signed 권한 영속성 — 재허용 후 여러 차례 리빌드·재서명에도 권한 유지됨(hasAX=true).
> 디버그 이벤트 로깅은 `defaults write com.tunemouse.TuneMouse debugEventLogging -bool true` 로 켤 수 있음(기본 off).

---

## 작업 항목

### 1. 이벤트 탭 생성/생명주기 (`EventTapController`)
- [ ] `CGEvent.tapCreate` 로 탭 생성
  - 위치: `.cgSessionEventTap`, 삽입: `.headInsertEventTap`, 옵션: `.defaultTap`(가공 가능)
  - 관심 이벤트(eventsOfInterest): **scrollWheel + 마우스 버튼**(left/right/other Down/Up/Dragged) — 인프라이므로 스크롤·버튼 모두 캡처(처리는 통과)
- [ ] `CFMachPort` → 런루프 소스 생성 → 런루프에 등록, `CGEvent.tapEnable`
- [ ] start() / stop() / setEnabled() 생명주기
- [ ] 권한 없으면 `tapCreate` 가 nil → 실패를 명확히 반환(크래시 금지)

**수용 기준**: 토글 on 시 탭 설치, off 시 해제. 권한 없으면 안전 실패.

### 2. C 콜백 트램펄린
- [ ] `CGEventTapCallBack` 은 컨텍스트를 캡처 못 하는 C 함수 → `userInfo(refcon)` 에 `Unmanaged` 로 컨트롤러 포인터 전달, 콜백에서 `Unmanaged.fromOpaque` 로 복원
- [ ] 콜백은 `.tapDisabledByTimeout` / `.tapDisabledByUserInput` 도 받음 → 처리(4번)
- [ ] 반환: (가공된) 이벤트 패스스루, 또는 소비(discard) 시 nil

**수용 기준**: 콜백이 메인 이벤트를 정상 수신, 통과 시 입력 무변화.

### 3. 이벤트 분류 + 트랙패드 제외 (`EventClassifier`)
- [ ] 스크롤 이벤트의 **연속성 판별**: `scrollWheelEventIsContinuous == 0` → 마우스 휠(가공 대상), `== 1` → 트랙패드/연속(통과)
- [ ] (보조) scroll phase 필드로 트랙패드 제스처 추가 판별
- [ ] 이벤트 종류 분류(휠 / 버튼N / 드래그) → 처리기로 라우팅할 형태로 정규화

**수용 기준**: 트랙패드 두 손가락 스크롤은 분류상 "통과"로 떨어진다.

### 4. 안전 설계 — 자동 재활성화
- [ ] `.tapDisabledByTimeout` 수신 시 `CGEvent.tapEnable(tap:enable:true)` 로 즉시 재활성화 + 로그(`tap` 카테고리)
- [ ] 콜백 핫패스 최소화(통과 단계는 거의 즉시 반환)로 타임아웃 예방

**수용 기준**: 인위적으로 탭이 꺼져도 자동 복구.

### 5. 처리 파이프라인 seam (`EventProcessor`)
- [ ] 최소 추상화: `protocol EventProcessor { func process(_:) -> 처리결과(통과/변형/소비) }`
- [ ] Phase 1 구현체는 **PassthroughProcessor**(항등) 하나 — 세 축은 이 인터페이스로 나중에 끼움
- [ ] (선택) 디버그용 스모크 테스트 처리기: 휠/버튼 이벤트를 로그로만 출력(검증용, 기본 off)

**수용 기준**: 통과 처리기로 입력 무변화. 디버그 처리기로 이벤트 수신 로그 확인.

### 6. 상태 연동 (토글 / 권한)
- [ ] `AppState.isEnabled` ↔ 탭 enable/disable 연결
- [ ] 접근성 권한 허용/해제에 따라 탭 설치/해제 (권한 생기면 자동 설치 시도)
- [ ] **권한 영속성 실검증**: self-signed 리빌드 후에도 권한 유지되는지 이 단계에서 확인

**수용 기준**: 토글·권한 상태와 탭 동작이 일치.

### 7. 패닉 키 (전역 토글 단축키)
- [ ] 전역 핫키 등록 (Carbon `RegisterEventHotKey` 권장 — 시스템 전역·소비 가능)
- [ ] 기본 조합 예: `⌃⌥⌘M` (커스터마이즈 UI는 후속)
- [ ] 누르면 `AppState.isEnabled` 토글 → 탭 즉시 on/off
- [ ] 앱 종료 시 핫키 해제

**수용 기준**: 어느 앱에서든 단축키로 기능 즉시 on/off.

---

## 아키텍처 결정 (구현 시 확정)

- **탭 콜백 실행 스레드**:
  - (A) **메인 런루프**(`.commonModes`) — 단순. 통과 단계는 충분히 빠름. 메인이 바쁘면 지연→타임아웃 위험(자동 재활성화로 방어).
  - (B) **전용 스레드 + 자체 런루프** — 메인 잔여부하·잔떨림 회피, 저지연. 핫패스에서 MainActor 상태를 직접 못 만져 nonisolated 플래그 캐싱 필요(동시성 관리 ↑).
  - **권장**: 인프라이므로 (B)를 염두에 두되, Phase 1은 **(A)로 시작**해 빠르게 검증 → 후속 단계에서 부하 보이면 (B)로 이전. (콜백 내부는 (B) 이전이 쉽도록 처리기/상태 접근을 분리 설계.)
- **활성화 플래그 접근**: 콜백 핫패스는 MainActor 홉 없이 읽도록 가벼운 스냅샷 플래그 사용(동시성 안전).
- **이벤트 마스크**: 스크롤 + 마우스 버튼 모두 캡처(처리는 통과). 키보드는 캡처 안 함(패닉 키는 별도 Carbon 핫키).

## 파일 레이아웃(안)
```
Sources/TuneMouse/EventTap/EventTapController.swift   # 탭 생성·생명주기·재활성화
Sources/TuneMouse/EventTap/EventTapCallback.swift      # C 콜백 트램펄린
Sources/TuneMouse/EventTap/EventClassifier.swift       # 마우스/트랙패드·종류 분류
Sources/TuneMouse/Pipeline/EventProcessor.swift        # seam: 프로토콜 + PassthroughProcessor
Sources/TuneMouse/Hotkey/PanicHotKey.swift             # 전역 핫키(패닉 키)
Sources/TuneMouse/Support/Log.swift                    # 카테고리 tap/hotkey 추가
```

## 실행 순서(제안)
1(탭 생성) → 2(콜백) → 5(통과 처리기) 로 "통과 탭"을 먼저 띄워 입력 무변화 확인 →
3(트랙패드 제외) → 4(재활성화) → 6(상태 연동·권한 검증) → 7(패닉 키).

## 위험 / 주의
- **입력 먹통 위험**: 탭 버그로 콜백이 멈추면 마우스가 잠깐 먹통될 수 있음 → (1) OS 타임아웃 자동 비활성화, (2) 자동 재활성화, (3) 패닉 키, (4) 개발 중 `run.sh` 로 즉시 종료 가능 — 4중 방어.
- **트랙패드 불가침**: 분류 단계에서 연속/제스처는 무조건 통과. 회귀 없도록 우선 처리.
- **App Store 불가 / 샌드박스 금지**: 전역 탭은 비샌드박스 전제(이미 충족).

## 검증 방법
- 통과 단계: 마우스 휠·클릭·버튼이 평소와 동일하게 동작(체감 변화 0).
- 디버그 처리기 on: `log stream --predicate 'subsystem == "com.tunemouse.TuneMouse"'` 로 휠/버튼 이벤트 수신 확인.
- 트랙패드: 두 손가락 스크롤이 가공 로그에 안 잡히고 정상 동작.
- 재활성화: 탭 강제 비활성화 후 자동 복구 로그 확인.
- 패닉 키: 임의 앱에서 단축키 → 메뉴바 아이콘 상태 토글 확인.

## 점검 후 보강 (Phase 1 리뷰)

다각도 점검 후 처리:
- **F1 [수정]** `.transformed` 반환을 `passRetained`로 — 새 이벤트 over-release 방지(Phase 2 변환기 대비). in-place 수정은 `.passUnchanged` 사용.
- **F2 [추가]** 워치독(3초)에서 `refreshAccessibility` → 런타임 권한 변화 자동 반영(재실행 불필요).
- **F4 [추가]** 워치독에서 `ensureEnabledIfInstalled` → 탭이 죽으면 재활성화(콜백 신호 누락 대비, 5번째 방어).
- **F11 [수정]** 상태 구독을 `DispatchQueue.main`으로 — 비기본 런루프 모드 지연 방지.

Phase 2 시작 시 처리(구체 변환기와 함께):
- **F7** 단일 processor → 순서 있는 **파이프라인(배열)** 구조.
- **F8** `process(type:event:)`에 **앱 컨텍스트**(frontmost bundle id 등) 추가 — 앱별 오버라이드(축3) 대비.

기록만(나중/주의):
- **F3** 권한 취소 시 상태 동기화(워치독이 일부 커버).
- **F5** 타임아웃 자동 재활성화 강제 트리거 검증은 미실시(입력 먹통 위험).
- **F6** 메인 런루프 → Phase 4(부드러운 스크롤) 부하 시 전용 스레드 이전 검토.
- **F9** 액션이 이벤트 합성 시 재진입 루프 가드 필요(Phase 3).
- **F10** 권한 미허용 시 매 시작 프롬프트 → 1회 제한 검토.
- **F12** 패닉 키 하드코딩(⌃⌥⌘M) → 커스터마이즈/충돌검사 후속.

## 금지 구역 메모
- 배포/공증 스크립트는 손대지 않음(프로덕션 단계). `build.sh`/`run.sh`만 로컬 도구로 갱신 가능.

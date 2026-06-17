# Phase 4 — 부드러운 스크롤 작업 파일

> 목표: 계단식 휠 스크롤을 **관성·이징이 있는 부드러운 픽셀 스크롤**로 변환.
> 백로그 직결: 스크롤 **스텝/듀레이션/부드러움 on·off**. 가장 복잡한 단계(애니메이션 루프 + 물리 모델 + 재진입).
> 관련: [SPEC.md](../SPEC.md), 이전: [phase-3-button-remap.md](phase-3-button-remap.md)

## 핵심 아이디어 (재진입이 자연스럽게 풀림)

- 우리 탭은 **비연속(discrete, `isContinuous==0`) 휠**만 파이프라인에 넘긴다. 연속(continuous) 스크롤은 `EventTapController.handle`에서 **변환기 도달 전에 통과**(트랙패드 제외 로직, Phase 1).
- 부드러운 스크롤 변환기는 **discrete 입력을 소비(discard)** 하고, 애니메이터가 **연속(픽셀) 스크롤 이벤트를 다수 합성·post**.
- 이 합성 연속 이벤트는 탭에 다시 들어와도 **continuous라 파이프라인을 건너뜀** → **재진입/이중 처리 없음**(F9가 자연 해소). (안전망으로 전용 EventSource 마커도 검토.)
- Phase 2(방향/속도)는 discrete 입력에 먼저 적용된 뒤 소비되므로 **합성 스트림에 재적용 안 됨** — 조합 정상.

## Definition of Done (완료 기준)

- [ ] 휠 한 노치가 **부드럽게 애니메이션**되어 스크롤된다(계단 → 연속).
- [ ] **부드러움 on/off** 토글. off면 Phase 2까지의 동작(즉시 스크롤)로 통과.
- [ ] **스텝**(노치당 거리)·**부드러움/듀레이션**·(선택)가속 파라미터로 조절된다.
- [ ] 방향 반전·속도 배율과 **자연스럽게 조합**된다.
- [ ] **트랙패드는 전혀 영향 없음**(이미 연속이라 통과).
- [ ] 설정이 영속화되고 **즉시 반영**된다.
- [ ] **앱별 부드러움 on/off**(축3) — 특정 앱(게임/미러링 등)에서 끄거나 통과.
- [ ] 메인 부하/입력 지연 없이 안정(탭 타임아웃 유발 금지).

---

## 작업 항목

### 1. 애니메이터 (`SmoothScrollAnimator`)
- [ ] 축별 잔여 거리(remaining) 누적 + 프레임마다 일부 emit
- [ ] 물리 모델 v1: **지수 이징(ease-out)** — `step = remaining * factor`, remaining 소진까지. 정지 임계값으로 종료.
- [ ] (선택) **가속**: 직전 노치와의 시간차로 step 스케일(빠른 연속 스크롤 = 큰 거리)
- [ ] 연속(픽셀) 스크롤 이벤트 합성·post (전용 `CGEventSource`)

**수용 기준**: 노치 입력 → 수십 프레임의 픽셀 스크롤로 부드럽게 감속.

### 2. 애니메이션 루프
- [ ] ~60–120Hz 구동. **v1: 메인 런루프 Timer**(콜백·상태 단일 스레드). 부하 보이면 CVDisplayLink/전용 스레드로 이전(F6).
- [ ] 잔여 0이면 루프 멈춤(상시 가동 금지)

**수용 기준**: 스크롤 중에만 루프 가동, 정지 시 중단.

### 3. 부드러운 스크롤 변환기 (`SmoothScrollTransformer`)
- [ ] discrete 휠 이벤트의 (방향/속도 적용된) delta를 애니메이터에 투입 + 원본 **discard**
- [ ] off면 `.passUnchanged`(즉시 스크롤 유지)
- [ ] 파이프라인 위치: scrollDirection·scrollSpeed **뒤**

**수용 기준**: on이면 부드럽게, off면 기존대로.

### 4. 파라미터 + 설정 모델 확장
- [ ] `ScrollConfig`(Phase 2)에 smooth 파라미터 추가: `smoothEnabled`, `step`, `smoothness`(또는 duration), (선택)`acceleration`
- [ ] 글로벌 + 앱별 동일 구조 재사용 → **앱별 부드러움 on/off**(축3)
- [ ] 영속화/라이브 반영(기존 ScrollSettingsStore 경로)

**수용 기준**: 값 저장/재시작 유지, 앱별 분기.

### 5. 설정 UI (스크롤 섹션 확장)
- [ ] 부드러운 스크롤 토글 + 스텝/부드러움 슬라이더
- [ ] (선택) 가속 토글

**수용 기준**: UI로 조절, 즉시 체감.

### 6. 검증
- [ ] 부드러운 스크롤 체감(계단 사라짐), on/off 즉시 전환
- [ ] 방향 반전·속도와 조합 정상
- [ ] 트랙패드 무영향, 재진입/폭주 없음
- [ ] 메인 지연·탭 타임아웃 없음(스트레스 스크롤)
- [ ] 앱별 off 동작(예: 특정 앱 통과)

---

## 아키텍처 결정 (구현 시 확정)

- **애니메이션 루프 구동**:
  - (A) **메인 Timer**(~60–120Hz) — 단순, 단일 스레드. → **v1 권장**.
  - (B) **CVDisplayLink/전용 스레드** — vsync 정렬·저지연, 단 합성 이벤트 post와 상태 공유에 락 필요(F6).
  - 권장: A로 시작, 부하/잔떨림 보이면 B.
- **물리 모델**: v1 지수 이징(구현 단순, 느낌 무난). 모멘텀/마찰 모델은 후속 튜닝.
- **재진입 방어**: 합성=연속 → 파이프라인 자연 우회. **안전망**으로 전용 EventSource + 마커 필드 확인 검토.
- **합성 이벤트 종류**: 픽셀 delta(`PointDelta`/`FixedPtDelta`) + `IsContinuous=1`로 emit(연속으로 인식되게).
- **조합 순서**: buttonRemap → scrollDirection → scrollSpeed → **smoothScroll** → (debug).

## 파일 레이아웃(안)
```
Sources/TuneMouse/Scroll/SmoothScrollAnimator.swift     # 잔여거리·이징·합성 post
Sources/TuneMouse/Transformers/SmoothScrollTransformer.swift
Sources/TuneMouse/Settings/ScrollSettings.swift         # ScrollConfig에 smooth 파라미터(기존 파일)
Sources/TuneMouse/Settings/SettingsView.swift           # 스크롤 섹션 확장(기존 파일)
```

## 실행 순서(제안)
4(파라미터 모델) → 1·2(애니메이터+루프, 우선 고정 파라미터로 합성 검증) → 3(변환기 연결) →
조합/재진입 검증 → 5(UI) → 6 최종 검증 → 앱별 off.

## 위험 / 주의
- **재진입/폭주**: 합성이 다시 smoothing 되면 무한 증폭 → continuous 우회 + (안전망)마커로 차단. 최우선 점검.
- **메인 부하/탭 타임아웃**: 고빈도 post가 메인을 막으면 탭 비활성 → 워치독이 복구하나, 루프 비용 최소화. 필요시 B로.
- **이중 부드러움**: 자체 스무딩 앱(브라우저 등)과 겹쳐 어색 → **앱별 off**로 제어.
- **트랙패드 불가침**: 연속은 계속 통과(변경 금지).
- **정지/방향전환**: 스크롤 멈춤·반대 방향 입력 시 잔여 거리/속도 정리(튐 방지).

## 검증 방법
- `debugEventLogging`로 입력 노치 소비 + 합성 프레임 흐름 확인.
- 부드러움 on/off 즉시 체감, 방향/속도와 조합.
- 스트레스 스크롤로 지연/타임아웃/폭주 없음 확인.
- 트랙패드 스크롤 무영향.

## 금지 구역 메모
- 배포/공증 스크립트는 손대지 않음. `build.sh`/`run.sh`만 로컬 도구로 갱신 가능.

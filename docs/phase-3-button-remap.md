# Phase 3 — 버튼 리매핑 작업 파일

> 목표: **액션 매핑 엔진(축2)** — 마우스 버튼 트리거 → 동작(키스트로크 발사 등) 매핑.
> 동시에 **앱별 오버라이드(축3)** 가 처음 실동작한다(Phase 2의 frontmost bundle id seam 사용).
> 구체 목표: **사파리에서 마우스 뒤로가기 버튼 동작**(버튼4 → ⌘[).
> 관련: [SPEC.md](../SPEC.md), 이전: [phase-2-scroll.md](phase-2-scroll.md)

## Definition of Done (완료 기준)

- [x] 추가 버튼(3·4·5 등)을 **키스트로크/동작에 매핑**할 수 있다.
- [x] 매핑된 버튼의 **down/up이 짝으로 소비**되어 원래 동작이 새지 않는다(스턱 없음).
- [x] **키스트로크 발사 엔진**으로 임의 단축키를 쏠 수 있다(⌘[ 등).
- [x] **사파리에서 마우스 뒤로가기 버튼이 동작한다** — 버튼3 → ⌘[ 로 검증(로그 key=33 flags=⌘).
- [x] **앱별 오버라이드**가 frontmost bundle id로 해석된다(축3 첫 실동작).
- [x] 매핑이 `UserDefaults`에 저장되고 **설정 UI로 편집**된다.
- [x] 매핑 없는 버튼/기능 off는 **통과**. 트랙패드·다른 버튼 영향 없음.

> 점검 후 추가: **커스텀 단축키 캡처**(임의 단축키 매핑, modifier 포함) 구현·검증(버튼3→⌘T 로그 key=17 flags=⌘). P3-1(버튼번호 읽기 위치) 정리.
> v1 이월: 클릭 종류(hold/double/drag) 타이밍 상태머신, 버튼 누름 캡처, 앱 미실행 시 선택 UI, 글로벌+앱별 병합 모드 — 후속.

---

## 작업 항목

### 1. 트리거 모델 (`ButtonTrigger`)
- [ ] 버튼 번호 + **클릭 종류**(v1: click) + modifier(⌘⌥⌃⇧) 조합
- [ ] 확장 대비: 클릭 종류 enum에 hold/double/drag 자리만(구현은 후속)

**수용 기준**: 트리거를 값으로 표현/비교 가능.

### 2. 액션 모델 + 키스트로크 엔진 (`ActionType`, `KeystrokeEngine`)
- [ ] `KeyCombo`(virtualKey + modifierFlags), `ActionType.keystroke(KeyCombo)`(v1 핵심)
- [ ] 키스트로크 합성/발사: `CGEvent(keyboardEventSource:virtualKey:keyDown:)` + flags + `post(tap:)`
- [ ] 키보드는 탭 안 함 → 합성 키 **재진입 루프 없음**(F9 안전)

**수용 기준**: 코드로 ⌘[ 등 임의 단축키 발사 가능.

### 3. 매핑 저장소 (`ButtonMappingStore`)
- [ ] 글로벌 매핑 + **앱별 오버라이드**(bundleID → 매핑) 구조 (SPEC 데이터 모델 원칙, Phase 2 ScrollSettings와 동일 패턴)
- [ ] 매핑 해석: 앱 오버라이드 있으면 그것, 없으면 글로벌(+모드: 수정/통과/커스텀 자리)
- [ ] Codable + `UserDefaults` 영속화

**수용 기준**: 값 저장/로드, 앱별 해석 동작.

### 4. 버튼 리매핑 변환기 (`ButtonRemapTransformer`)
- [ ] otherMouse/left/right Down·Up에서 트리거 매칭
- [ ] 매칭 시: 동작 발사 + 이벤트 **소비(discard)**. **매핑된 버튼의 down/up 둘 다 소비**(스턱 방지)
- [ ] 발사 시점 v1: **mouseDown에 발사 + 매칭 up 소비**(즉시성)
- [ ] 미매칭은 통과

**수용 기준**: 매핑 버튼 누르면 동작 발사, 원래 클릭 안 샘. 다른 버튼 정상.

### 5. 앱별 오버라이드 해석 (축3 첫 실동작)
- [ ] `ProcessingContext.frontmostBundleID`(Phase 2) → 저장소의 `resolved(forBundleID:)` 로 매핑 선택
- [ ] 글로벌 vs 앱별 우선순위 확정

**수용 기준**: 같은 버튼이 앱에 따라 다른 동작.

### 6. 설정 UI (매핑 편집 — 기본형)
- [ ] 매핑 목록(버튼/조건 → 동작) 추가·삭제
- [ ] 버튼 캡처(누른 버튼 감지), 동작 선택(키스트로크/프리셋), 단축키 캡처
- [ ] 앱별: "현재 앱에 추가" 정도(풍부한 앱 선택 UI는 후속)

**수용 기준**: UI로 매핑을 만들고 즉시 반영.

### 7. 시스템 동작 프리셋
- [ ] 뒤로(⌘[)/앞으로(⌘])·미션컨트롤(^↑)·앱익스포제(^↓)·스페이스 좌우(^←/^→) 등 **키스트로크 프리셋**
- [ ] (후속) 전용 API 필요한 동작(특정 스페이스 이동 등)은 별도

**수용 기준**: 프리셋 선택만으로 흔한 동작 매핑.

### 8. 검증
- [ ] **사파리: 버튼4 → ⌘[ 로 뒤로가기** 동작
- [ ] 스턱 버튼 없음(매핑/해제 후 일반 클릭 정상)
- [ ] 앱별: 사파리에서만 적용, 다른 앱은 통과/글로벌
- [ ] 매핑 영속화, 기능 off 통과, 트랙패드 무영향

---

## 아키텍처 결정 (구현 시 확정)

- **발사 시점**: v1은 **mouseDown 발사 + 매칭 up 소비**. 클릭(up 기준)·홀드·더블·드래그는 **타이밍 상태머신** 필요 → 확장 항목.
- **down/up 짝 소비**: 매핑된 버튼은 down·up 모두 discard(한쪽만 소비하면 시스템이 눌린 상태로 인식 → 스턱). 발사는 한 번.
- **modifier 매칭**: `event.flags` 로 트리거 modifier 매칭. v1 기본 지원.
- **키스트로크 합성/포커스**: 합성 키는 frontmost 앱으로 전달(`post(tap:)`). 콜백 내 발사 vs 다음 런루프 디스패치 — 타이밍 확인.
- **시스템 동작 = 키스트로크 프리셋**: 미션컨트롤/스페이스 등 대부분 단축키로 커버 → 엔진 하나로 다수 동작. 전용 API는 후속.
- **앱별 우선순위**: 앱 오버라이드 > 글로벌. "통과(예외)" 모드도 표현 가능하게.

## 파일 레이아웃(안)
```
Sources/TuneMouse/Actions/ActionTypes.swift            # KeyCombo, ActionType, 프리셋
Sources/TuneMouse/Actions/KeystrokeEngine.swift        # 키스트로크 합성/발사
Sources/TuneMouse/Actions/ButtonTrigger.swift          # 트리거 모델
Sources/TuneMouse/Actions/ButtonMappingStore.swift     # 글로벌+앱별 매핑 + 영속화
Sources/TuneMouse/Transformers/ButtonRemapTransformer.swift
Sources/TuneMouse/Settings/...                          # 매핑 편집 UI
```

## 실행 순서(제안)
2(엔진)·1(트리거)·3(저장) 모델/엔진 → 4(변환기) → 5(앱별 해석) →
**시드 매핑으로 사파리 뒤로가기 먼저 검증**(8 일부) → 6(UI) → 7(프리셋) → 8 최종 검증.

## 위험 / 주의
- **스턱 버튼**: down/up 짝 소비 안 하면 버튼이 눌린 상태로 고착 → 최우선 방어. (개발 중 패닉 키/`run.sh`로 탈출)
- **글로벌 매핑의 광역 영향**: 의도치 않은 앱에서 발동 → 앱별 예외/통과로 제어(축3).
- **발사 포커스/타이밍**: 합성 키가 엉뚱한 앱에 가지 않게.
- **modifier 오매칭**: 트리거에 modifier 없을 때 ⌘ 누른 클릭이 매칭되지 않도록 정확히.
- **재진입**: 키스트로크는 키보드 미탭이라 안전. 단, 향후 버튼→마우스/스크롤 합성 추가 시 가드 필요(F9).

## 검증 방법
- `debugEventLogging` 로 버튼 트리거 매칭/발사 로그 확인.
- 사파리에서 버튼4 → 뒤로가기 체감.
- 매핑 후 일반 좌/우클릭이 정상인지(스턱 점검).
- 트랙패드·미매핑 버튼 통과 확인.

## 금지 구역 메모
- 배포/공증 스크립트는 손대지 않음. `build.sh`/`run.sh`만 로컬 도구로 갱신 가능.

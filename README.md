# TuneMouse

Mac Mouse Fix 류의 macOS 마우스 향상 앱(메뉴바 상주). 스크롤 변환·버튼 리매핑·앱별 오버라이드를
**확장형 세 축**으로 설계해 쓰면서 하나씩 튜닝한다.

> 현재 **Phase 0(셋업) 완료** — 실행되는 메뉴바 골격 + 권한 플로우 + 빌드/서명. 기능(이벤트 탭)은 Phase 1+.

## 핵심 제약

- **접근성(Accessibility) 권한 필수** — 마우스 이벤트 가공에 필요(시스템 설정에서 직접 허용).
- **트랙패드는 건드리지 않는다** — 마우스 휠/버튼만 가공, 트랙패드 제스처는 OS 기본 통과.
- **App Store 배포 불가** — 전역 이벤트 탭은 샌드박스에서 차단. 직접 배포(공증 DMG) 전제.

## 요구 환경

- Apple Silicon(arm64), macOS 14+
- Swift 6 / SwiftPM (풀 Xcode 불필요)

## 빌드 & 실행

```bash
./scripts/build.sh && ./scripts/run.sh
```

- `build.sh` — `swift build` → `.app` 번들 조립 → 코드 서명(`dist/TuneMouse.app`)
- `run.sh` — 기존 인스턴스 종료 후 실행
- 릴리스 빌드: `CONFIG=release ./scripts/build.sh`

## 코드 서명

개인용 단계는 self-signed 인증서(`TuneMouse Dev`)로 서명해 리빌드 시 권한 재허용을 막는다.
인증서 생성/사용법은 [docs/signing.md](docs/signing.md) 참고. 인증서가 있으면 `build.sh`가 자동 인식한다.

## 로그

Console.app에서 subsystem `com.tunemouse.TuneMouse` 로 필터링.

## 문서

- [SPEC.md](SPEC.md) — 기획/협의 정리, 세 축 설계, 백로그
- [docs/phase-0-setup.md](docs/phase-0-setup.md) — Phase 0 작업/완료 기준
- [docs/phase-0-refinements.md](docs/phase-0-refinements.md) — Phase 0 마무리 다듬기
- [docs/signing.md](docs/signing.md) — 코드 서명 가이드

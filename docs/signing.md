# 코드 서명 가이드 (개인용 단계 — self-signed)

> 왜 필요한가: macOS는 접근성 권한을 **앱의 코드 서명 정체성**에 묶는다.
> ad-hoc 서명(`-`)은 리빌드할 때마다 정체성이 흔들려 권한을 다시 허용해야 할 수 있다.
> 안정적인 self-signed 인증서로 서명하면 리빌드해도 정체성이 같아 **권한이 유지**된다.

## 1. 인증서 한 번 생성 (키체인 GUI)

1. **키체인 접근**(Keychain Access) 앱 실행
2. 상단 메뉴 → **인증서 지원** → **인증서 생성…**
   *(Certificate Assistant → Create a Certificate…)*
3. 입력값:
   - **이름**: `TuneMouse Dev`  ← 정확히 이 이름이면 빌드 스크립트가 자동 인식
   - **신원 유형**: `자체 서명 루트` (Self Signed Root)
   - **인증서 유형**: **`코드 서명`** (Code Signing)
   - **기본값 무시(Let me override defaults)**: ✅ 체크 권장
     - 다음 화면에서 **유효 기간(Validity Period)** 을 길게 (예: `3650` 일 = 10년).
       체크 안 하면 기본 365일 후 만료되어 재발급해야 함.
   - 나머지는 기본값으로 끝까지 진행 → 생성
4. 생성된 인증서는 **로그인(login) 키체인**에 들어간다.

## 2. 생성 확인 (터미널)

```bash
security find-identity -p codesigning
```
출력 목록에 `TuneMouse Dev` 가 보이면 성공.

> ⚠️ `-v`(valid) 옵션을 붙이면 안 보인다. self-signed 인증서는 신뢰 설정이 안 돼
> `CSSMERR_TP_NOT_TRUSTED` 상태이고 `-v`는 이를 걸러내기 때문. **서명에는 전혀 문제 없다**
> (신뢰 여부는 Gatekeeper/공증 검증용이고, TCC 권한은 인증서 정체성에 묶임).
> 그래서 `build.sh`도 `-v` 없이 탐지한다. 굳이 신뢰 설정(관리자 암호 필요)을 할 필요는 없다.

## 3. 서명해서 빌드

빌드 스크립트가 `TuneMouse Dev` 인증서를 **자동 탐지**한다. 그냥:
```bash
./scripts/build.sh && ./scripts/run.sh
```
- 다른 이름의 인증서를 쓰려면: `CODESIGN_IDENTITY="내 인증서명" ./scripts/build.sh`
- 자동 탐지 이름을 바꾸려면: `DEV_CERT_NAME="다른 이름" ./scripts/build.sh`

서명 정체성 확인:
```bash
codesign -dv dist/TuneMouse.app 2>&1 | grep -E 'Authority|Signature|Identifier'
```
`Authority=TuneMouse Dev` 가 보이면 self-signed로 서명된 것.

## 4. 처음 한 번 일어나는 일들 (정상)

- **키 사용 허용 프롬프트**: 첫 서명 시 "codesign이 키체인의 키로 서명하려 합니다" 창이 뜰 수 있음
  → **항상 허용(Always Allow)** 클릭하면 이후 안 물어봄.
- **접근성 권한 1회 재허용**: ad-hoc → self-signed 로 정체성이 바뀌므로, 전환 직후 **딱 한 번** 접근성 권한을 다시 허용해야 함.
  - 시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용에서 기존 TuneMouse 항목을 **빼고(–)**, 새로 실행된 앱을 다시 허용.
  - 이후 같은 인증서로 리빌드하는 한 권한은 **계속 유지**된다.

## 5. 주의

- 이 self-signed 인증서는 **개인 개발용**이다. 남에게 배포(GitHub 공개/유료)할 땐 Apple Developer ID 인증서 + 공증(notarization)이 필요하며, 그건 프로덕션 단계에서 Xcode와 함께 다룬다.
- 인증서/키(`*.p12`, `*.cer`)는 `.gitignore`에 이미 포함됨 — 저장소에 올리지 말 것.

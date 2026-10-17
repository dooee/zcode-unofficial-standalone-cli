# zcode-cli-install-helper

Z.AI의 오픈소스 **공식 ZCode CLI**를 공식 소스에서 빌드해 `zcode` 명령으로 설치해 주는 커뮤니티 설치 도우미입니다. 데스크톱 앱도, 포크도 아닙니다.

![ZCode CLI 시작 화면, GLM Coding Plan 계정으로 GLM-5.3 실행](images/tui-welcome.png)

> **독립 프로젝트입니다.** 설치되는 `zcode`는 [zai-org/ZCode](https://github.com/zai-org/ZCode) (Apache-2.0)를 공식 빌드 명령으로 빌드한 공식 CLI 그대로입니다. 이 설치 도우미만 커뮤니티 프로젝트이며, Z.AI와 제휴하거나 보증받지 않았습니다.

ZCode는 Z.ai GLM 모델(GLM-5.3 등)을 위한 터미널 하네스이며, GLM Coding Plan 구독으로 그대로 사용할 수 있습니다. Z.AI는 현재 이를 데스크톱 앱으로만 배포하며, CLI 소스는 공개되어 있지만 모노레포 빌드 지식이 필요합니다. 이 도우미가 그 간극을 메웁니다.

[English README (README.md)](../README.md)

> **계정 관련 안내 (업스트림 버그, 2026-10 기준):** ZCode 데스크톱 앱을 한 번도 실행한 적 없는 머신에서는 `zcode login` 이 완료되어도 발급 토큰을 모델 API가 거절합니다. 현재는 **데스크톱 앱을 통한 최초 1회 인증**이 필요하며, 이후 CLI는 완전히 독립 동작합니다. 자세한 내용은 [계정 설정 섹션](#계정-설정과-현재의-일회성-데스크톱-요구), 업스트림 추적은 [zai-org/feedback#1001](https://github.com/zai-org/feedback/issues/1001).

## 어떤 경우에 쓰나요

- **공식 하네스 사용의 안정성.** 설치되는 것은 공식 CLI 그 자체입니다. 데스크톱 앱과 동일한 버전 번호, 동일한 TUI, 동일한 세션과 credential 구조를 가집니다. 래퍼도, 추출한 바이너리도, 별도로 만든 UI도 없습니다. 항상 업스트림 코드를 업스트림 방식대로 빌드해 실행합니다.
- **Orca 같은 ADE에서의 독립 사용.** 에이전트 개발 환경은 에이전트 슬롯과 하네스를 1:1로 연결합니다 (claude는 Claude Code, codex는 Codex). GLM도 자기 전용 하네스 슬롯이 필요한데, 이 도구는 공식 `zcode` 정체성 그대로 설치되므로 ADE가 공식 CLI로 인식합니다. Orca에서 `worktree create --agent zcode` 동작을 확인했습니다.
- **모노레포 지식 없이 터미널 워크플로만 필요할 때.** pnpm, 워크스페이스, lockfile 지식이 필요 없습니다. 명령 한 번으로 빌드와 설치가 끝납니다.
- **검증 가능한 설치를 선호할 때.** 공식 태그 tarball을 GitHub에서 내려받아 내 컴퓨터에서 빌드합니다. 미리 빌드된 남의 바이너리를 실행하지 않습니다.

## 지원 플랫폼

| 플랫폼 | 상태 |
|---|---|
| macOS (Apple Silicon, arm64) | 검증 완료. 설치, TUI, headless, `zcode login`, Orca 연동 테스트 |
| macOS (Intel, x64) | 동작할 것으로 예상, 미실측 |
| Linux (x64, ARM64) | 동작할 것으로 예상, 미실측 |
| Windows | 미지원. WSL 미실측 |

## 요구사항

인스톨러를 받을 때:

| 구성 요소 | 필요 여부 | 비고 |
|---|---|---|
| git | 권장 | 이 저장소를 받는 가장 쉬운 방법. 단 필수는 아님 (아래 ZIP 내려받기 참고) |

인스톨러 실행과 이후 CLI 구동 모두:

| 구성 요소 | 필요 여부 | 비고 |
|---|---|---|
| Node.js | 필수, 24 이상 | 설치 시와 CLI 런타임 모두 필요합니다 (CLI가 `node:sqlite`를 쓰는데 이 API는 Node 24부터 안정 상태라, 더 오래된 Node에서는 CLI 자체가 깨집니다). 24.x와 26.x에서 검증했습니다. 업스트림 파일에 보이는 `24.14.0`은 개발용 고정 버전이지 요구 사양이 아닙니다. nodejs.org 에서 24 이상이면 아무 버전이나 괜찮고, nvm이나 버전 고정 지식도 필요 없습니다. 인스톨러가 설치 전에 버전을 검사해 부족하면 명확한 메시지로 중단합니다. |
| 네트워크 | 필수 | GitHub(소스, 태그)와 npm registry |

인증할 때 (최초 1회, 업스트림 버그 우회):

| 구성 요소 | 필요 여부 | 비고 |
|---|---|---|
| ZCode 데스크톱 앱 | 1회 | 설치 후 한 번 로그인하고 종료하면 동작하는 credential이 발급됩니다 (상단 안내 및 [feedback#1001](https://github.com/zai-org/feedback/issues/1001) 참고). 이후 CLI 실행과 사용에는 필요 없습니다. 계정을 바꾸거나 credential 갱신이 필요할 때는 다시 필요할 것으로 예상됩니다. |

설치 과정 자체는 Node.js와 네트워크만 있으면 됩니다. git, curl, pnpm, corepack은 물론 OS의 `tar` 명령까지 직접 준비할 필요가 없습니다. 빌드에 필요한 나머지는 모두 `~/.zcode-cli/tools`에 자동으로 격리 설치되고, 전역 환경은 절대 수정하지 않습니다.

새로 세팅한 macOS에서 네이티브 의존성 단계가 실패하면 `xcode-select --install` 로 Xcode Command Line Tools를 설치하세요.

## 계정 설정과 현재의 일회성 데스크톱 요구

인증은 2단계 설계입니다. `zcode login` 이 먼저 OAuth 신원 토큰을 받고, CLI가 이를 `api.z.ai/api/auth/z/login` 에서 모델 API가 실제로 받아들이는 코딩 플랜 API 키로 교환합니다. 현재는 두 결함이 겹쳐 있습니다:

1. 교환이 서버에서 거절됩니다 ("Z.ai user information is invalid", [zai-org/feedback#1001](https://github.com/zai-org/feedback/issues/1001) 로 보고됨. macOS에서도 종단 간 실패를 재현했습니다).
2. 교환이 실패하면 CLI는 원본 OAuth 토큰을 API 키인 양 그대로 보내는 조용한 폴백에 빠집니다 (배포 번들 내 `business?.token ?? oauth`). 그래서 명확한 "자격 교환 실패" 대신 모델 API에서 오해를 부르는 401 "Invalid Authentication Token" 이 나옵니다. 이 상태의 지문으로, 로그의 요청 메타데이터에 `"account_uuid":""` 가 남습니다.

실무적으로 의미하는 것:

- 데스크톱 앱을 설치한 적이 있는 머신이라면 동작하는 API 키 credential이 이미 `~/.zcode/v2/credentials.json` 에 있고 CLI가 자동으로 사용합니다. 이후 CLI는 완전히 독립 동작합니다.
- 깨끗한 머신에서는 자격 발급 목적으로만 데스크톱 앱이 현재 한 번 필요합니다. 발급된 머신의 `~/.zcode/v2/credentials.json` 을 복사해도 됩니다.
- Z.AI가 교환 엔드포인트를 수정하면 일회성 요구는 사라지고 `zcode login` 만으로 충분해집니다.

## 설치

git이 있는 경우:

```bash
git clone https://github.com/dooee/zcode-cli-install-helper.git
cd zcode-cli-install-helper
./install.sh
```

git 없이 (ZIP 내려받기): GitHub에서 이 저장소를 열고 초록색 **Code** 버튼의 **Download ZIP** 으로 내려받은 뒤 압축을 풀고 실행합니다 (`unzip` 은 macOS에 기본 포함, 다른 압축 도구도 가능):

```bash
unzip zcode-cli-install-helper-main.zip
cd zcode-cli-install-helper-main
./install.sh
```

설치 스크립트 자체는 git을 전혀 쓰지 않습니다. 공식 ZCode 소스 tarball은 Node.js fetch로 내려받습니다.

기타 형태:

```bash
./install.sh --latest          # 최신 공식 태그
./install.sh --tag v3.15.1     # 특정 태그 지정
./install.sh --lang ko         # 한국어 메시지 (기본: en)
./install.sh --force           # 같은 태그라도 다시 빌드
```

설치 후:

```bash
zcode          # TUI
zcode -p "안녕"  # headless 원샷
```

계정 인증 (위 업스트림 버그 때문에 최초 1회): ZCode 데스크톱 앱을 설치하고 거기서 한 번 로그인한 뒤 종료하세요. CLI가 그 credential을 자동으로 재사용합니다. 깨끗한 머신에서 `zcode login` 만으로는 현재 401 오류에 도달하며, Z.AI가 [#1001](https://github.com/zai-org/feedback/issues/1001) 을 수정하면 단독으로 충분해집니다.

`~/.local/bin` 이 PATH에 없었다면, 인스톨러가 셸 설정에 추가할 두 줄과 적용할 `source` 명령을 그대로 출력해 줍니다. 중요한 점은 PATH 변경이 이미 열려 있는 터미널 세션에는 적용되지 않는다는 것입니다. 출력된 `source` 명령을 실행하거나 터미널을 새로 연 뒤에 첫 `zcode`를 실행하세요.

## 버전 관리와 릴리스

두 가지 버전 라인이 의도적으로 공존합니다.

- **인스톨러 자체**는 자체 semver를 따릅니다 (`~/.zcode-cli/INSTALLER_VERSION`, 현재 0.4.0). 변경 이력은 이 저장소의 git 히스토리와 GitHub Releases로 관리됩니다.
- **설치되는 CLI**는 업스트림 태그를 따릅니다 (`~/.zcode-cli/INSTALLED`, 예: v3.15.1). 빌드 산출물은 이 저장소에 커밋되지 않으며, 모든 사용자가 공식 태그 tarball을 자기 머신에서 빌드합니다.

## 업데이트

두 가지 방식이 있고, 둘 다 알림이 먼저이며 실행은 요청할 때만 합니다.

- `zcode-update` 는 설치된 태그와 최신 공식 태그를 비교해 보여줍니다. `--apply` 를 붙이면 최신 태그로 다시 빌드합니다.
- 설치된 `zcode` 명령도 하루에 한 번만(캐시: `~/.zcode-cli`) 확인해서, 새 ZCode 버전이 출시되었으면 "zcode-cli-install-helper 업데이트가 필요하다"는 알림을 출력하고 CLI를 정상 시작합니다. 확인 요청은 4초 제한이 있고 네트워크 실패 시 조용히 넘어가므로 작업을 막지 않습니다.

설치 후 구조:

```
~/.zcode-cli/
  INSTALLED              # 설치된 태그, 예: v3.15.1
  LANG                   # 메시지 언어 (en 또는 ko)
  src/                   # 공식 소스와 빌드 결과
  tools/                 # 격리된 빌드 도구 (자동 설치)
  bin/                   # install.sh 사본, 업데이트 확인기
  cache/                 # 내려받은 tarball
~/.local/bin/zcode           # 래퍼: 일일 알림 후 공식 바이너리 실행
~/.local/bin/zcode-update    # 요청 시 업데이트 확인 / 적용
```

빌드는 새 디렉토리에서 진행하고 성공 후에만 교체하므로, 업데이트 실패가 현재 설치를 망가뜨리지 않습니다.

## 검증 이력

| 항목 | 날짜 | 환경 | 결과 |
|---|---|---|---|
| v3.15.1 전체 설치 | 2026-10-11 | macOS arm64, Node 24와 26 | 설치, TUI, headless `-p`, 계정 연동, Orca `--agent zcode` 확인 |
| `zcode login` (OAuth) | 2026-10-11 | macOS arm64 | 플로우는 완료되지만, 깨끗한 credential 저장소에서는 토큰이 모델 API에서 거절됨 (업스트림 [#1001](https://github.com/zai-org/feedback/issues/1001)). 데스크톱 발급 API 키는 정상 동작 |

## 트러블슈팅

**`zcode -p` 실행 시 404 "Not Found" (standalone CLI)**

2026-10-13부터 관측된 서버 측 회귀: standalone CLI가 코딩 플랜 요청을 `api.z.ai/api/anthropic`에서 공식 게이트웨이 `zcode.z.ai/api/v1/ultra-zai/...`로 재작성하는데, 이 게이트웨이가 현재 `metadata` 필드가 포함된 요청을 404로 거부합니다. CLI는 항상 metadata를 보내므로 모든 모델 호출이 실패하고, 동일한 요청을 `api.z.ai`로 직접 보내면 성공합니다. 데스크톱 앱은 이 재작성을 쓰지 않아 영향이 없습니다.

우회: provider baseUrl을 같은 호스트에 점 하나를 붙여 지정하세요. 게이트웨이 재작성은 호스트명을 정확한 문자열로 비교하므로 `api.z.ai.` 는 재작성을 건너뛰면서 같은 엔드포인트로 해석됩니다:

```bash
node -e '
const fs = require("fs"), os = require("os"), p = os.homedir() + "/.zcode/v2/provider_config.json";
const d = JSON.parse(fs.readFileSync(p, "utf8"));
d.config.providerConfigRules.providerRules = [
  { providerId: "account:zai-individual-coding-plan",
    config: { api: { baseUrl: "https://api.z.ai./api/anthropic" } } }
];
fs.writeFileSync(p, JSON.stringify(d, null, 2));
console.log("baseUrl 오버라이드 적용");
'
```

Z.AI가 게이트웨이를 수정하면 이 규칙을 제거하세요.

**`zcode -p` 실행 시 `Unauthorized` / 401**

같은 증상에 두 가지 원인이 있습니다:

1. 깨끗한 머신에서 첫 로그인을 `zcode login` (OAuth)으로 한 경우: 저장된 토큰을 모델 API가 거절합니다. 업스트림 버그로 [zai-org/feedback#1001](https://github.com/zai-org/feedback/issues/1001) 를 참고하고, 위 계정 설정 섹션의 안내를 따르세요.
2. CLI와 ZCode Desktop이 `~/.zcode/v2/credentials.json` 을 공유하는 경우: Desktop 사용 중 `zcode login` 을 실행하면 `account-provider:...:auth-source` 가 `manual` 에서 `oauth` 로 바뀌면서 동작하던 설정이 깨질 수 있습니다. 실제로 동작하는 경로는 API 키이므로, 이 값을 `manual` 로 되돌리면 복구됩니다.

## 제약

- 빌드 기반이라 설치와 업데이트에 수 분 걸립니다.
- macOS arm64에서만 검증했습니다. Linux는 같은 경로로 동작할 것으로 보이지만 미실측입니다.
- Windows는 지원하지 않습니다 (WSL 미실측).
- `ZCode` 와 `Z.AI` 는 Z.AI의 상표입니다. 이 프로젝트는 Apache-2.0 소스 빌드를 자동화할 뿐입니다.

## 라이선스

- 이 저장소(스크립트와 문서): **MIT**
- 빌드 대상인 ZCode 소스: **Apache-2.0**, 저작권과 고지는 원 저작자에게 있습니다

## 번역 기여

인스톨러 메시지는 `lang/en.sh` 와 `lang/ko.sh` 에 변수 할당 형태로 들어 있습니다. 번역을 개선하거나 새 언어를 추가하려면 `lang/en.sh` 를 복사해 값을 번역하세요 (%s 자리표시자는 유지). 셸 로직은 손댈 필요가 없습니다.

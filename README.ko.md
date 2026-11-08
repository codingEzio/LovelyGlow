<p align="center">
  <img src="docs/icon.svg" width="120" height="120" alt="Lovely Glow">
</p>

# Lovely Glow

[English](README.md) · [简体中文](README.zh-Hans.md) · [繁體中文](README.zh-Hant.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md)

선택 사항인 Pixel 글꼴은 DeparturePixelZh Compact 0.1.1을 사용하며 저장소에 포함되지 않습니다. 패키징 전에 `python3 script/get_compact_font.py`로 고정 버전을 다운로드하고 검증하세요. 자세한 내용은 [의존성](DEPENDENCIES.md)을 참조하세요. 로컬 글꼴을 쓰려면 빌드할 때 `LOVELYGLOW_PRIVATE_FONT`에 파일 경로를 지정하세요. 글꼴은 저장소 밖이나 무시되는 `Local/`에 보관하고 패키징 전에 검증합니다. 선택적으로 `LOVELYGLOW_PRIVATE_FONT_NOTICES`에 해당 고지 디렉터리를 지정하세요. 생략하면 패키지에 고지가 없다고 표시합니다. 설정을 유지하려면 무시되는 `Local/font-input.json`을 사용하세요. [의존성](DEPENDENCIES.md)을 참조하세요.

현재 활성 창에 하나의 빛나는 테두리를 그리는 macOS 네이티브 메뉴 막대 앱입니다. 내용을 어둡게 하거나 창을 배치하거나 다른 앱의 창에 붙지 않습니다.

## 동작

Glow를 켜면 전면 앱의 현재 창을 따라갑니다. 제목 없는 작은 보조 창은 기본적으로 제외하며 More에서 포함할 수 있습니다. 자체 메뉴, Cmd+Tab, Spotlight에서는 이전 대상을 유지합니다. 전체 화면, Mission Control, 작업 영역을 채운 창에서는 숨깁니다. 클릭을 통과시키고 키보드 포커스를 빼앗지 않습니다.

메뉴 막대 팝오버에서 색, 크기, 동작, 등장 방식, 글꼴을 조절합니다. System이 기본이며 포함된 Pixel Compact도 선택해 저장할 수 있습니다. Instant와 Seamless는 하나의 오버레이를 공유하고 현재 화면의 갱신에 맞춥니다. 코어 테스트는 실제 제스처, 부드러움, 픽셀 정렬을 증명하지 않습니다. Stage Manager, 사용자 정의 창 모양, 향후 macOS의 Space 감지에는 제한이 있습니다.

## 소스 빌드

Apple Silicon, macOS 27 이상, 선택된 호환 Xcode／Swift 6.2 이상 SDK가 필요합니다. 내려받는 Swift 패키지나 인접 저장소 의존성은 없습니다. Apple의 정상 절차로 Xcode 설치와 라이선스 확인을 먼저 마칩니다.

```sh
swift build --jobs 2 --scratch-path Local/swift-build --product LovelyGlow
just test
python3 -m unittest discover -s script -p test_migrate_settings.py
```

`just`는 기존 명령의 바로가기입니다. 같은 코어 테스트는 `swift test --jobs 2 --scratch-path Local/swift-test`입니다. 합성 데이터를 사용하며 앱 실행, 손쉬운 사용 권한 요청, 설치, 로그인 항목 변경을 하지 않습니다. `SWIFT_JOBS` 기본값은 2, `SWIFT_SCRATCH_PATH`는 `Local/swift-test`입니다. 잘못된 옵션은 실패합니다.

### 개발 앱 실행

`./script/dev.sh --run`은 개인 인증서 없이 임시 서명한 앱을 빌드하고 터미널에서 실행합니다. Control-C 또는 앱의 종료 명령으로 멈춥니다. `./script/dev.sh --build`는 빌드만 합니다. 빌드할 때마다 별도의 `Local/lovelyglow-dev.*`에 출력하고 `Local/swift-dev-build` 캐시를 재사용합니다. 앱을 멈춘 뒤 불필요한 출력은 직접 삭제할 수 있으며, 빌드 중이 아닐 때 캐시도 삭제할 수 있습니다. 실패한 출력도 남습니다.

개발 앱 설정은 제품과 별도인 `~/Library/Application Support/com.github.codingEzio.LovelyGlow.Development/config.toml`에 유지됩니다. 설정을 버릴 때만 해당 디렉터리를 삭제하세요. 로그인 시작을 켰다면 앱을 삭제하기 전에 개발 앱에서 끄세요. 정리 후에도 macOS에 권한 기록이 남을 수 있습니다. 선택 글꼴이 없어도 시스템 글꼴을 사용할 수 있습니다.

## 서명과 설치

`config/product.conf`가 있으면 우선 사용합니다. 없으면 같은 제품 식별자와 빈 서명 값을 가진 `config/product.public.conf`를 읽습니다. 소스 후보는 개인 설정을 포함하지 않습니다. 실행 파일 컴파일만으로 서명된 앱이 검증되지는 않습니다.

```sh
just stage
just install
```

이 명령에는 소유자가 설정한 인증서와 서명 식별자가 필요합니다. Stage는 사용 중인 앱을 멈추지 않고 별도 후보를 만듭니다. Install은 기존 서명 요구사항과 일치할 때만 `~/Applications/LovelyGlow.app`을 교체하고 실행합니다. 임시 서명이나 새 bundle ID로 우회하지 않습니다. 패키징에는 iconutil／sips, 선택적 rsvg-convert, Python 아이콘 대체 경로를 사용합니다.

권한 버튼을 눌러 손쉬운 사용 권한을 요청합니다. 시작할 때는 요청하지 않습니다. 권한이 없어도 일반 앱 전환은 창 시스템 경계를 사용하지만 드래그 추적은 약해집니다. 로그인 시작은 사용자가 켠 SMAppService만 사용합니다. HTTP 서비스, LaunchAgent, Process Compose는 없습니다.

## 데이터와 이전

0.7.9／33부터 유일한 설정 위치는 `~/Library/Application Support/com.alex.LovelyGlow/config.toml`입니다. 실행 설정을 소스에 다시 쓰지 않습니다. 설치기는 이전 서명 앱의 메타데이터에서 옛 경로를 읽고, 이전 프로세스를 멈춘 뒤 바이트 단위로 복사하고 다시 읽습니다. 대상에 다른 내용이 있으면 어느 파일도 덮어쓰지 않고 중단합니다. 원본은 복구용으로 남깁니다. 새 설치는 Application Support를 바로 사용합니다. 빌드 출력은 Git에서 제외한 Local／dist에 있습니다.

## 라이선스와 소스 검토

README 마크는 codingEzio가 만든 별도의 문서용 SVG이며 [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)을 따릅니다. 제품 아이콘, 글꼴 및 제3자의 권리는 바뀌지 않습니다.

자체 소프트웨어는 [MIT](LICENSE)입니다. 글꼴은 [원래 OFL과 구성 요소 고지](Resources/Licenses/NOTICE.md)를 유지합니다. [LICENSE-SCOPE.md](LICENSE-SCOPE.md)가 범위를 구분합니다. 이 저장소는 권리가 미확인된 원래 아이콘을 제외하고 명시된 자체 CC BY 4.0 기하학 플레이스홀더를 사용합니다. 개인 패키징의 원래 아이콘을 공개할 수 있다는 뜻은 아닙니다.

소스 이력과 검증 범위는 [PUBLICATION.md](PUBLICATION.md)를 참조하세요.

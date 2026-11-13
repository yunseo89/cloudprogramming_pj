# MovieLog — 개인 영화 평점 및 감상 기록

영화 제목·별점·관람일·감상을 기록하고, 다시 찾아 수정하거나 삭제하는 작은 Flutter 앱입니다. 기존 [MovieLog](https://github.com/yunseo89/movielog)의 일부 코드를 재사용했습니다.

**별도 백엔드·로그인·Docker·AWS가 없습니다.** 기록은 같은 기기와 브라우저에 저장됩니다. TMDB 토큰 없이도 ‘직접 기록하기’로 모든 기록 관리 기능을 사용할 수 있습니다.

## 실행

준비: [Flutter stable SDK](https://docs.flutter.dev/install)와 Chrome. 검증 버전은 Flutter **3.47.9 / Dart 3.13.7**입니다. `flutter doctor`로 설치를 확인하세요.

```sh
git clone https://github.com/yunseo89/cloudprogramming_pj.git
cd cloudprogramming_pj
flutter pub get
flutter run -d chrome --web-port=7357
```

실행 중 터미널의 `q`로 종료합니다. 다시 실행할 때도 **같은 주소·포트·브라우저 프로필**을 사용하세요. `flutter run -d chrome`이 새 임시 프로필을 쓰면 이전 기록이 보이지 않을 수 있습니다. 지속 저장을 확인할 때는 아래 방법으로 본인 Chrome의 `http://localhost:7357`을 열어 사용하세요.

```sh
flutter run -d web-server --web-hostname=localhost --web-port=7357
```

위 명령은 Flutter 화면을 브라우저에 전달하는 개발 도구입니다. Python이나 별도 API 서버를 설치할 필요가 없습니다.

## 사용 순서

1. ‘직접 기록하기’에서 제목, 1~5점 별점, 관람일, 감상을 입력하고 저장합니다.
2. 제목과 감상은 공백만 입력할 수 없습니다. 제목은 100자, 감상은 500자까지입니다.
3. 목록에서 기록을 확인하고 ‘수정’으로 내용을 바꿉니다. ‘삭제’는 확인 후 실행됩니다.
4. 등록 최신순·평점 높은순·제목순으로 정렬하고, 제목으로 내 기록을 검색합니다.
5. 브라우저를 새로고침해 같은 기록이 보이는지 확인합니다.

저장 공간 오류가 나면 입력과 기존 기록을 유지하고 재시도를 안내합니다. 브라우저 데이터를 지우거나 시크릿 창을 닫으면 기록이 사라질 수 있습니다. 여러 탭에서 동시에 수정하거나 기기 간 동기화하는 기능은 지원하지 않습니다.

## TMDB 영화 검색 (선택)

직접 입력 외에 TMDB에서 영화 제목을 검색해 기록할 수 있습니다. 검색 결과의 첫 페이지(최대 20편)를 사용합니다. 같은 TMDB 영화는 기존 기록의 수정 창으로 연결됩니다. 토큰이 없거나 통신이 실패해도 직접 입력한 기록은 계속 사용할 수 있습니다.

1. [TMDB API 설정](https://www.themoviedb.org/settings/api)에서 **API Read Access Token**을 준비합니다.
2. `config/tmdb.example.json`을 `config/tmdb.local.json`으로 복사하고 빈 값에 본인 토큰을 넣습니다.
3. 아래 명령으로 실행합니다.

```sh
flutter run -d web-server --web-hostname=localhost --web-port=7357 --dart-define-from-file=config/tmdb.local.json
```

`*.local.json`은 Git에서 제외됩니다. Flutter Web의 설정값은 빌드에 포함되어 브라우저에서 읽을 수 있으므로 비밀 서버 키를 넣지 마세요. 본인 실습용 TMDB 읽기 토큰만 사용하고, 이 설정으로 만든 빌드 파일을 공개 배포하지 마세요. 실제 토큰을 사용한 TMDB 실서비스 연결은 이번 환경에서 검증하지 않았습니다.

This product uses the TMDB API but is not endorsed or certified by TMDB.

## 검증

```sh
flutter analyze
flutter test --reporter expanded
flutter build web --release --no-web-resources-cdn
```

20개 자동 테스트가 모델·저장·CRUD·필수 입력·저장 실패·정렬·검색·가상 TMDB 응답을 검사합니다. 정적 분석과 Flutter Web release 빌드도 통과했습니다. 실제 Chromium에서 등록·수정·삭제와 새로고침 후 기록 유지를 확인했습니다. 실제 토큰을 사용한 TMDB 연결은 미검증입니다.

한글 글꼴과 CanvasKit을 빌드에 포함해 직접 입력 기능이 외부 CDN에 의존하지 않도록 했습니다. 빌드 결과를 로컬에서 확인하려면 Node.js 18 이상에서 `node tool/serve.mjs`를 실행하고 `http://localhost:7357`을 여세요. 일반 사용에는 위의 Flutter 실행 명령이면 충분합니다.

## 코드 구조

- `lib/main.dart`: 앱 시작과 저장소 준비
- `lib/app.dart`: 기록 목록·입력·수정·삭제·영화 검색 화면
- `lib/diary_controller.dart`: 기록 변경, 정렬·검색, 저장 성공 후 상태 반영
- `lib/data/models/`: 기록·TMDB 영화 데이터
- `lib/data/services/`: 기기 저장과 영화 검색
- `test/`: 모델·저장·화면·서비스 테스트

Flutter 기본 `ChangeNotifier`와 `ListenableBuilder`를 사용합니다. 직접 의존성은 Flutter, Dio, shared_preferences입니다. 회원가입·로그인·별도 평점 서버는 포함하지 않습니다.

## 원본 코드

[MovieLog](https://github.com/yunseo89/movielog)의 커밋 `ed26549dac423b712fa2cd1f4a820973cc67a39d`에서 TMDB DTO·포스터 위젯·색상을 재사용했습니다. Dio 서비스 구조와 정수 별점 입력 방식은 이번 앱에 맞게 바꿨습니다. 기기 저장·기록 Controller·직접 입력·정렬·검색·테스트는 이번 프로젝트에서 작성했습니다. 원본 저장소는 수정하지 않았습니다.

Noto Sans KR의 라이선스는 `assets/fonts/OFL.txt`에 포함했습니다.

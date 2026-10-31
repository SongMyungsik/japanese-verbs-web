# 일본어 동사 활용 학습 앱 (Flutter)

한국어 사용자를 위한 일본어 동사 활용 학습 앱. 동사 597개, 활용형 13가지.
이 저장소는 **웹 공개판**이다. 안드로이드폰·아이폰 브라우저에서 GitHub Pages로 실행하며
(<https://songmyungsik.github.io/japanese-verbs-web/>), 개발·테스트는 Windows 데스크톱에서도 돌아간다.
비공개 저장소 `japanese_verbs_app`에서 갈라져 나왔고, 두 저장소는 자동으로 동기화되지 않는다.

- 화면 글자, 코드 주석, 커밋 메시지는 **한국어**로 쓴다. 주석은 "왜"를 짧게 적는 지금 밀도를 따른다.
- 사용자와는 한국어로 대화한다.

## 화면 구성

하단 탭: **홈 / 학습 / 퀴즈 / 앱 소개** (`lib/screens/app_shell.dart`). 홈 화면에서는 하단 탭을 숨기고
'학습 시작' 버튼과 '앱 소개' 링크로 들어간다.

- **학습** 탭(`study_screen.dart`): 2×2 파스텔 타일 — 동사 목록 / 단계별 / 주제별 / JLPT / 퀴즈 / 오늘의 복습.
  단계·주제·JLPT 메뉴 항목에는 학습 진도 막대.
- **퀴즈** 탭: 퀴즈 설정 / 퀴즈 시작 / 복습·오답 노트. 문제 방식은 4지선다와 **글자 맞추기**
  (히라가나 조각을 눌러 답을 만듦 — 폰에 일본어 자판이 없어도 되게 하려고 직접 입력 대신 이 방식을 씀).
- **활용표**(`conjugation_screen.dart`)는 탭이 아니라 동사를 누르면 그 탭 안에 push된다
  (route 이름 `AppNav.conjugationRoute`). 다른 탭으로 옮기면 활용표만 닫히고 보던 목록은 남는다.
- 학습·퀴즈 탭은 각자 Navigator를 가진다(`TabNavigator`, `AppNav.tabNavigatorKeys`).

## 폴더

```
lib/models/      verb.dart(동사·활용형), study_scope.dart(단계·주제·JLPT 범위), verb_extras.dart(예문·짝)
lib/providers/   verb_provider(목록·필터·즐겨찾기·진도), quiz_settings(퀴즈 설정, DB 저장),
                 quiz_controller(퀴즈 한 판), app_nav(탭)
lib/services/    conjugator(활용 규칙 엔진), quiz_generator, verb_repository(SQLite), speech_service(TTS),
                 db_platform(플랫폼별 DB 구현 선택: _native, _web), web_speech(웹 음성)
lib/widgets/     furigana.dart(한자 위 읽기), common.dart(그룹 색, 읽기 토글, 읽어 주기 버튼)
assets/data/     verbs.json, expected_forms.json, examples.json, verb_pairs.json
assets/fonts/    NotoSansJP-subset.ttf (앱에서 쓰는 글자만 남긴 고딕 글꼴), OFL.txt
tool/            데이터 검증·생성 스크립트 (아래 참고)
review/          예문·짝 검토 기록 CSV. 엑셀로 열린다(UTF-8 BOM).
web/             웹 진입점. sqlite3.wasm·sqflite_sw.js는 `dart run sqflite_common_ffi_web:setup`으로 만든 파일
.github/workflows/deploy.yml  main에 푸시하면 테스트 후 Pages에 배포
```

## 데이터

- **verbs.json** — 동사 데이터의 **원본**. 엑셀에서 내보내지 않고 이 파일을 직접 고친다. 필드: id, text, reading, meaning,
  group(ichidan/godan/irregular), ending, stative("TRUE"/"FALSE" 문자열), topics(`|`로 여러 개),
  learning_stage(1~6), jlpt_level(N5~N1/미분류), jlpt_verified. 참/거짓이 문자열로 올 수 있어
  `Verb._bool`이 둘 다 받는다. 6단계(경어)는 아직 동사가 없어 메뉴에 '준비 중'.
- 앱은 시작할 때 verbs.json을 DB에 덮어쓰고, JSON에서 빠진 동사는 DB·복습 기록·즐겨찾기에서 지운다.
- **expected_forms.json** — 활용 정답. 1~377번은 엑셀 표, 378번부터는 JMdict 대조 후 엔진 결과로 만듦.
  쓰지 않는/성립하지 않는 칸은 `null`. `test/conjugator_test.dart`가 597개 전부를 확인한다.
- **examples.json** — 동사별 예문 `{id: {ja, reading, ko}}`. reading은 한자만 히라가나로 바꾸고
  가나·가타카나·문장부호·숫자는 ja와 똑같이 둔다(후리가나 정렬에 필요). Claude가 쓴 초안을
  사용자가 검토해 반영했다(`review/examples.csv`, 검토 표시·메모 보관용 — 이 파일의 본문은 갱신하지 않음).
- **verb_pairs.json** — 자동사·타동사 짝 `[{intransitive, transitive}]` 75쌍. 검토 완료(`review/verb_pairs.csv`).
  見える-見る, 聞こえる-聞く는 지각 동사라 파생 짝이 아니어서 뺐다.

## 작업 순서 (중요)

### 동사를 추가·수정했을 때
1. `python tool/check_jmdict.py <JMdict_e.gz>` — 그룹·어미를 사전과 대조.
   JMdict: `curl -L -o JMdict_e.gz http://ftp.edrdg.org/pub/Nihongo/JMdict_e.gz` (검사용, 앱에 넣지 않음, 저장소에도 넣지 않음)
   - `SPECIAL`(엔진이 모르는 특수 활용)이나 `MISMATCH`가 나오면 **먼저** 엔진(`conjugator.dart`의 `_special`)이나
     데이터를 고친다. 엔진에 예외를 추가하면 스크립트의 `HANDLED`에도 적는다.
2. 문제가 없으면 `dart run tool/dump_forms.dart assets/data/expected_forms.json`으로 정답 갱신.
   **엔진 결과를 검증 없이 정답으로 넣지 말 것** — 틀린 활용이 정답으로 굳는다.
   갱신 전후 diff로 의도한 동사만 바뀌었는지 확인한다(예: くれる를 고칠 때 읽기가 같은 暮れる가 같이 바뀐 적 있음).
3. 새 동사에 예문을 추가하고 `python tool/check_examples.py`.
4. 새 한자가 생겼으면 글꼴을 다시 만든다(아래).
5. `flutter analyze`, `flutter test`.

### 글꼴
가나·한자는 앱에 넣은 Noto Sans JP로, 한글은 기기 기본 한글 고딕으로 그린다(`ThemeData.fontFamily`).
기기의 일본어 기본 글꼴이 명조라서 이렇게 했다. **TextStyle에 `locale: ja`를 앱 전체에 주지 말 것** —
한글까지 명조로 가늘게 나온 적이 있다.
데이터에 새 한자가 생기면: `pip install fonttools` 후
`python tool/subset_font.py <원본 NotoSansJP[wght].ttf>` (원본: github.com/google/fonts/ofl/notosansjp).
없는 글자는 기기 글꼴로 대신 그려질 뿐 깨지지는 않는다.

### 앱 아이콘
`node tool/make_icon.js .`로 Android·웹·Windows·스토어용 파일을 만든다(`npm i puppeteer-core` 필요, 저장소에 넣지 않음).
두 저장소의 그림이 같아야 하므로 아이콘을 바꾸면 양쪽 모두 다시 만든다.

### DB
`verb_repository.dart`, 지금 **version 5**. 표: verbs, reviews(복습 기록), favorites, settings(퀴즈 설정 JSON).
스키마를 바꿀 때는 버전을 올리고 `onUpgrade`에 단계별 마이그레이션을 추가한다. **복습 기록은 절대 지우지 않는다.**
`test/repository_test.dart`에 예전 버전 DB에서 올라오는 테스트가 있다.

## 알아 둘 점

- **활용 엔진 특수 동사**: する·来る(·복합), 行く(て·た형), ある(ない), くださる·なさる·おっしゃる·いらっしゃる
  (ます형 ~います, 명령형 ~い), くれる(명령형 くれ), 愛する(愛す처럼). 존경어·くれる의 가능·의지·수동·사역·
  사역수동·희망형은 실제로 쓰지 않아 null(활용표 '―', 퀴즈 출제 안 함). 상태동사(stative)도 일부 형이 null.
- **후리가나**(`splitRuby`): 한자 덩어리와 나머지로 나누고, 나누는 방법이 여러 가지면 한자 한 글자에 읽기
  두 글자 정도인 쪽을 고른다(昨日の=きのう|の 문제 때문). `tool/check_examples.py`의 `split_ruby`가 같은 방식 —
  한쪽을 고치면 다른 쪽도 고친다.
- **읽어 주기**는 히라가나 읽기를 TTS에 넘긴다(한자는 엔진이 잘못 읽을 수 있어서). 기기에 일본어 음성이 없으면 안내 스낵바.
  웹은 flutter_tts 대신 `web_speech_web.dart`로 브라우저 음성을 직접 쓴다. 플러그인은 언어를 비워 둘 수 있어
  페이지 언어(ko)로 읽혔기 때문이다. `lang`은 반드시 ja-JP로 준다.
- **웹 저장소**: DB는 브라우저 IndexedDB에 있다(`sqflite_databases`). 기기 간 공유되지 않는다.
  패키지를 올린 뒤에는 setup을 다시 돌려 web/의 두 파일을 맞춘다. 앱 안에서 쓰는 경로는 `--base-href`에 맞아야 한다.
- `flutter analyze`의 info 1건(`db_platform_native.dart`의 sqflite import가 불필요하다는 메시지)은 **일부러 둔 것**.
  지우면 안드로이드에서 DB 팩토리가 달라질 수 있다.
- 퀴즈 설정·즐겨찾기·복습 기록은 DB에 저장되어 유지된다. 읽기 표시(눈 아이콘)는 저장하지 않는다.

## Windows에서 스크립트 실행 시 주의 (이전 작업에서 겪은 문제)

- Python을 **표준입력(heredoc)으로 실행하면 한자·특수문자가 다른 인코딩으로 읽혀** 문자열 치환이 조용히 실패한다.
  치환 스크립트는 UTF-8 파일로 저장한 뒤 실행하고, 치환할 문자열이 있는지 `assert`로 확인한다.
- 화면 출력에 한글·일본어가 깨지면 `sys.stdout.reconfigure(encoding='utf-8')`.
  `python -I`는 `PYTHONIOENCODING`과 사용자 site-packages(fonttools 등)를 무시한다.
- `dart run`은 화면에 "Running build hooks..."를 섞어 쓰므로 결과는 파일로 저장한다(dump_forms.dart가 그렇게 함).
- 파일 편집 도구가 문자열 안의 `​` 같은 이스케이프를 실제 문자로 바꿔 넣을 수 있다.
  보이지 않는 문자는 `String.fromCharCode(...)`로 쓴다.

## 남은 일 / 아이디어

- 6단계(경어) 동사 데이터 추가
- `jlpt_verified`가 false인 급수 표시
- 다크 모드 점검

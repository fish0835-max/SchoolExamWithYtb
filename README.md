# 國小學習遊戲

讓孩子在看 YouTube 的同時學習課程。
進入播放頁先答對題目才能開始看，答對後計時 30 分鐘，時間到畫面強制被題目覆蓋，答對才能繼續看。

## 功能

- 🎬 YouTube 嵌入播放（App 內，非外部）
- ⏱ 可設定的計時器（預設 30 分鐘）
- 📝 全螢幕題目覆蓋層（無法關閉，答對才解除）
- 🔒 家長 PIN 保護設定（孩子無法存取設定）
- 📚 支援數學 + 國文，1-6 年級
- 🤖 AI 動態出題（Claude API via Firebase Cloud Functions）
- 📷 照片出題（上傳教材照片）
- 🔍 影片內搜尋（關鍵字或貼上 YouTube 網址）
- 📊 學習記錄統計

## 技術棧

| 層級 | 技術 |
|------|------|
| App | Flutter (Android / iOS / Windows / macOS / Web) |
| 後端 | Firebase (Cloud Functions + Firestore + Storage) |
| AI 出題 | Claude API（透過 Firebase Cloud Functions 呼叫） |
| 狀態管理 | Riverpod |
| 路由 | go_router |

## 快速開始

### 前置需求

- [Flutter SDK](https://flutter.dev) >= 3.19（需要 `dart:ui_web`）
- [Firebase CLI](https://firebase.google.com/docs/cli) + Firebase 專案
- [YouTube Data API v3 Key](https://console.cloud.google.com)（關鍵字搜尋功能）
- Node.js >= 18（Firebase Functions 與題庫生成工具）

### 1. 設定 Firebase

```bash
# 安裝 Firebase CLI
npm install -g firebase-tools

# 登入並連結專案
firebase login
firebase use --add

# 部署 Cloud Functions
cd functions
npm install
cd ..
firebase deploy --only functions

# 設定 Cloud Functions 環境變數
firebase functions:secrets:set CLAUDE_API_KEY
```

> Firebase 設定檔（`google-services.json` / `GoogleService-Info.plist` / `firebase_options.dart`）
> 已加入 `.gitignore`，需自行從 Firebase Console 下載放置。

### 2. 設定 YouTube API Key

```bash
# 複製範本並填入 key
cp assets/.env.example assets/.env
# 編輯 assets/.env，填入：
# YOUTUBE_API_KEY=your-youtube-data-api-v3-key
```

### 3. 生成題庫

```bash
cd tools/question_generator
npm install

# 生成 2 年級數學題庫
npx ts-node generator.ts --subject=math --grade=2 --output=json

# 複製到 Flutter assets
cp output/questions.json ../../assets/questions/questions.json
```

### 4. 執行 Flutter App

```bash
# 安裝依賴
flutter pub get

# 執行（Web）
flutter run -d chrome

# 執行（Android）
flutter run -d android

# 執行（Windows）
flutter run -d windows
```

## 專案結構

```
SchoolExam/
├── lib/
│   ├── main.dart                    # 程式入口（Firebase / dotenv / SQLite 初始化）
│   ├── app.dart                     # GoRouter 路由設定
│   ├── core/
│   │   ├── config/app_config.dart   # 設定常數（含 debug timer 覆寫）
│   │   ├── models/                  # 資料模型（Question, ChildUser...）
│   │   ├── providers/               # Riverpod 全域狀態
│   │   └── services/                # 商業邏輯（Timer, Question, Settings...）
│   └── features/
│       ├── child/                   # 孩子端（孩子可見）
│       │   ├── home/                # 主畫面（YouTube 網址輸入）
│       │   ├── youtube_player/      # YouTube 播放器（Web iframe / Native）
│       │   └── quiz_overlay/        # 題目覆蓋層
│       ├── parent/                  # 家長端（PIN 保護）
│       │   ├── pin_gate/            # PIN 輸入頁
│       │   ├── dashboard/           # 家長設定主頁
│       │   ├── subject_range/       # 科目範圍設定
│       │   ├── timer_config/        # 計時器設定
│       │   └── photo_upload/        # 照片出題
│       └── profile/                 # 學習記錄
├── assets/
│   ├── .env                         # API Keys（不上傳 Git）
│   └── questions/questions.json     # 靜態題庫（可離線使用）
├── functions/                       # Firebase Cloud Functions (TypeScript)
│   └── src/index.ts                 # generateQuestion / generateFromPhoto
└── tools/
    └── question_generator/          # 題庫生成工具
```

## 使用流程

### 孩子使用
1. 選擇頭像（選孩子）
2. 輸入或貼上 YouTube 網址，或使用搜尋功能
3. **先答對題目**才能開始播放
4. 計時結束 → 畫面被題目覆蓋
5. 答對題目 → 覆蓋消失，繼續觀看
6. 計時器重置，重複流程

### 家長設定
1. 長按主畫面右上角設定圖示
2. 輸入 4-6 位 PIN 碼（首次使用自動設定）
3. 調整設定：
   - 科目/年級/課次範圍
   - 觀看時間、答題數量
   - 出題來源（固定/AI/照片）

## 架構圖

> 以下圖表由 [Mermaid](https://mermaid.js.org/) 繪製，GitHub / VS Code 原生渲染。
> 完整 PlantUML 原始檔位於 [`docs/architecture.puml`](docs/architecture.puml)。

---

### 1. 資料夾結構與模組職責

```mermaid
graph TD
  subgraph lib["lib/"]
    MAIN["main.dart\n載入 .env / Firebase / SQLite"]
    APP["app.dart\nGoRouter 路由"]

    subgraph core["core/"]
      CFG["config/app_config.dart\nAppConfig · ParentSettings"]
      MDL["models/\nQuestion · ChildUser · LearningSession"]
      PRV["providers/auth_provider.dart\nactiveChild · parentMode · timerProvider"]
      SVC["services/\nTimerNotifier · QuestionService\nSettingsService · LocalDbService"]
      STUB["services/stub/\n條件編譯替代檔\n(Web / Desktop)"]
    end

    subgraph features["features/"]
      subgraph child["child/"]
        CSEL["home/child_select_screen.dart"]
        HOME["home/home_screen.dart\nYouTube 網址輸入"]
        PLAYER["youtube_player/\nyoutube_player_screen.dart\nweb_player.dart (Web only)"]
        QUIZ["quiz_overlay/quiz_overlay.dart\n全螢幕題目覆蓋層"]
      end
      subgraph parent["parent/ (PIN 保護)"]
        PIN["pin_gate/"]
        DASH["dashboard/"]
        TCFG["timer_config/"]
        SRNG["subject_range/"]
        PHO["photo_upload/"]
      end
      PROFILE["profile/profile_screen.dart"]
    end
  end

  MAIN --> APP
  APP --> CSEL & HOME & PLAYER & PIN & DASH
  PLAYER --> QUIZ
  QUIZ --> SVC
  PLAYER --> PRV
  DASH --> TCFG & SRNG & PHO
  SVC --> STUB
  PRV --> CFG & MDL
```

---

### 2. 模組溝通（分層架構）

```mermaid
graph TB
  subgraph UI["UI Layer"]
    direction LR
    HOME2["HomeScreen"]
    PLAYER2["YoutubePlayerScreen"]
    QUIZ2["QuizOverlay"]
    DASH2["ParentDashboard"]
  end

  subgraph STATE["State Layer · Riverpod Providers"]
    direction LR
    P1["activeChildProvider\nStateProvider&lt;ChildUser?&gt;"]
    P2["timerProvider\nStateNotifierProvider&lt;TimerNotifier&gt;"]
    P3["settingsServiceProvider\nProvider&lt;SettingsService&gt;"]
    P4["questionServiceProvider\nProvider&lt;QuestionService&gt;"]
  end

  subgraph SVC2["Service Layer"]
    T["TimerNotifier\n(倒數邏輯)"]
    S["SettingsService\n(SharedPreferences)"]
    Q["QuestionService\n(Strategy 路由)"]
  end

  subgraph DATA["Data Layer"]
    DB["SQLite\n固定題庫"]
    FB["Firebase Cloud Functions\nAI / 照片出題"]
    SP["SharedPreferences\n設定 · PIN · 近期影片"]
  end

  HOME2 -->|push route| PLAYER2
  PLAYER2 -->|show overlay| QUIZ2
  PLAYER2 -->|watch| P2
  PLAYER2 -->|read| P3
  QUIZ2 -->|getNextQuestion| P4
  QUIZ2 -->|onComplete callback| PLAYER2
  DASH2 -->|save settings| P3

  P2 --> T
  P3 --> S
  P4 --> Q

  Q -->|fixed| DB
  Q -->|ai / photo| FB
  S --> SP
```

---

### 3. 主要學習流程

```mermaid
sequenceDiagram
  actor 小朋友
  participant HomeScreen
  participant YoutubePlayerScreen
  participant TimerNotifier
  participant QuizOverlay
  participant QuestionService

  小朋友->>HomeScreen: 輸入 YouTube 網址
  HomeScreen->>YoutubePlayerScreen: navigate /child/player?videoId=X

  activate YoutubePlayerScreen
  YoutubePlayerScreen->>YoutubePlayerScreen: _showOverlay = true\niframe 設為 hidden

  YoutubePlayerScreen->>QuizOverlay: 顯示題目覆蓋層
  activate QuizOverlay
  QuizOverlay->>QuestionService: getNextQuestion('math')
  QuestionService-->>QuizOverlay: Question

  QuizOverlay-->>小朋友: 顯示題目 ＋ 倒數

  alt 答對（達到解鎖題數）
    QuizOverlay-->>YoutubePlayerScreen: onComplete()
    deactivate QuizOverlay
    YoutubePlayerScreen->>TimerNotifier: setup(秒數) → start()
    YoutubePlayerScreen->>YoutubePlayerScreen: iframe 顯示 → playVideo
    YoutubePlayerScreen-->>小朋友: 🎬 開始播放

    loop 每秒
      TimerNotifier-->>YoutubePlayerScreen: emit TimerState
      YoutubePlayerScreen-->>小朋友: 更新倒數 pill
    end

    TimerNotifier->>YoutubePlayerScreen: onExpired()
    YoutubePlayerScreen->>YoutubePlayerScreen: pauseVideo + hideForOverlay
    YoutubePlayerScreen->>QuizOverlay: 再次顯示（回到答題）

  else 答錯 / 超時
    QuizOverlay->>QuestionService: 取下一題
    QuizOverlay-->>小朋友: 顯示下一題
  end

  deactivate YoutubePlayerScreen
```

---

### 4. 新增 Plugin（以「題目來源」為例）

```mermaid
classDiagram
  class QuestionSourceStrategy {
    <<interface>>
    +getQuestion(settings) Future~Question?~
  }

  class FixedBankSource {
    -_db LocalDbService
    +getQuestion(settings) Future~Question?~
  }

  class AIGeneratedSource {
    -_functions FirebaseFunctions
    +getQuestion(settings) Future~Question?~
  }

  class PhotoSource {
    +getQuestion(settings) Future~Question?~
  }

  class YourNewSource {
    +getQuestion(settings) Future~Question?~
  }

  class QuestionService {
    -_fixed FixedBankSource
    -_ai AIGeneratedSource
    -_photo PhotoSource
    -_yourNew YourNewSource
    +getNextQuestion(subject) Future~Question?~
    -_selectSource(settings) QuestionSourceStrategy
  }

  QuestionSourceStrategy <|.. FixedBankSource
  QuestionSourceStrategy <|.. AIGeneratedSource
  QuestionSourceStrategy <|.. PhotoSource
  QuestionSourceStrategy <|.. YourNewSource : ① 實作介面
  QuestionService --> FixedBankSource
  QuestionService --> AIGeneratedSource
  QuestionService --> PhotoSource
  QuestionService --> YourNewSource : ② 在此註冊
```

**新增 Plugin 步驟：**

| 步驟 | 動作 | 檔案 |
|------|------|------|
| ① | 建立新類別實作 `QuestionSourceStrategy` | `lib/core/services/your_source.dart` |
| ② | 在 `QuestionService._selectSource()` 新增 `case` | `lib/core/services/question_service.dart` |
| ③ | 在 `AppConfig` 新增來源名稱常數 | `lib/core/config/app_config.dart` |
| ④ | 在家長設定 UI 新增下拉選項 | `lib/features/parent/subject_range/subject_range_screen.dart` |
| ⑤ | （選用）在 `ParentSettings` 新增 plugin 專屬欄位並更新 `toJson` / `fromJson` | `lib/core/config/app_config.dart` |

---

## 驗證

```bash
# 測試計時器（app_config.dart 設 debugDurationSeconds = 30）
# 確認 30 秒後覆蓋層出現

# 驗證孩子模式
# 確認設定入口不可見（無法點選進入）

# 驗證 PIN 保護
# 長按設定圖示 → 輸入 PIN → 確認可進入設定

# 驗證題庫
cd tools/question_generator
npx ts-node validator.ts --file=../../assets/questions/questions.json
```

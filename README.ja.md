# EMBER

[English](README.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md)

[**EMBER公式サイトを見る →**](https://ember-sleep.vercel.app/)

![Swift](https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-iOS-0D96F6?logo=swift&logoColor=white)
![HealthKit](https://img.shields.io/badge/HealthKit-Read--only-FF2D55?logo=apple&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Backend-3FCF8E?logo=supabase&logoColor=white)
![OpenRouter AI](https://img.shields.io/badge/OpenRouter-AI-6C5CE7)
![Next.js](https://img.shields.io/badge/Next.js-16-000000?logo=nextdotjs&logoColor=white)
![Vercel](https://img.shields.io/badge/Vercel-Deployed-000000?logo=vercel&logoColor=white)

![EMBER — 睡眠は身につけられるスキル](promotional-materials/poster-01-sleep-is-a-skill.png)

**睡眠は身につけられるスキル。EMBERがそのコーチになります。**

EMBERはiPhone向けのパーソナル・レストコーチです。睡眠データ、
カレンダー、サーカディアンリズム、地域の天気、寝室環境をまとめ、
今夜のための明確でパーソナライズされたプランを作成します。

## EMBERでできること

- クールダウン、消灯、起床時刻をまとめたナイトプランを作成。
- Apple Healthの睡眠・アクティビティ情報を読み取り専用で利用。
- 早朝の予定、夜のイベント、旅行、日の出、気温に合わせて自動調整。
- ユーザー自身のプランに基づくストリーミングAI Rest Coach。
- AIを設定していない場合も、ルールベースのコーチを利用可能。
- Sleep Window Training、CBT-Iに基づく睡眠効率、Thermal Wind-Down。
- 起床アラームと就寝前リマインダー。
- 音声によるMind Dumpを編集可能なテキストに変換。
- Box Space、フレンド、ポイント、報酬、Blue Boxスキンによる習慣化支援。

## プロダクト体験

### Tonight

次に何をすべきか、そしてプランがなぜ変わったのかを一つの画面で確認できます。

### AgendaとDaily Rhythm

カレンダーの予定をパーソナライズされた体内リズム曲線上に表示します。
早起きや夜遅い予定がある場合、EMBERが事前に睡眠プランを調整します。

### Rest Coach

現在のプラン、睡眠傾向、カレンダー、エビデンスに基づいて回答します。
OpenRouterを設定すると、OpenAI互換APIから回答をストリーミングできます。

### Rest Lab

Sleep Window TrainingとThermal Wind-Downにより、睡眠科学を実行しやすく
記録可能な小さなアクションへ変換します。

### Box Space

良い習慣で睡眠ポイントとBlue Boxスキンを獲得できます。Supabaseが
アカウント、フレンド、リクエスト、報酬、ランキングを管理します。

## 技術スタック

- **iOS：** Swift 5、SwiftUI、Swift Charts、Swift Concurrency、Combine
- **Apple Framework：** HealthKit、EventKit、CoreLocation、AlarmKit、
  UserNotifications、BackgroundTasks、Speech、AVFoundation、Keychain
- **バックエンド：** Supabase Swift、Supabase Auth、PostgreSQL、RPC
- **AI：** OpenRouter、OpenAI-compatible Chat Completions、SSEストリーミング
- **環境データ：** Open-Meteo API
- **公式サイト：** Next.js 16、React 19、TypeScript、CSS、pnpm、Vercel
- **プロダクト映像：** Remotion 4、React、TypeScript
- **開発ツール：** XcodeGen、Swift Package Manager

## リポジトリ構成

```text
Ember/                    iOSアプリ
  AI/                     LLMクライアントとカレンダー分類
  Alarms/                 起床アラームとリマインダー
  Algorithms/             リズム、睡眠ウィンドウ、温度、プランのロジック
  Calendar/               EventKit連携
  Data/                   アプリ状態、Supabase、ライブデータ生成
  Health/                 HealthKit連携と睡眠指標
  Services/               天気、位置、睡眠環境、キャッシュ、フレンド
  Views/                  SwiftUIインターフェース
  Assets.xcassets/        Appアイコン、Blue Boxスキン、ブランド素材
official-website/         Next.js公式サイト
video/                    Remotionプロダクト映像
promotional-materials/    ポスター、SNS素材、機能モジュール画像
project.yml               XcodeGen設定
```

## iOSアプリを起動する

推奨環境：

- macOSとXcode 16以降
- iOS 17.6 deployment target
- HealthKit、位置情報、マイク、通知の確認には実機を推奨

プロジェクトを開きます：

```bash
open Ember.xcodeproj
```

Xcodeで自分のDevelopment Teamと一意のBundle Identifierを選び、
`Ember` targetをビルドしてください。

`project.yml`を変更した後に再生成する場合：

```bash
brew install xcodegen
xcodegen generate
```

AlarmKit対応SDKでビルドし、iOS 26.1以降で実行した場合はシステム起床
アラームを利用できます。通常のリマインダーはメインのdeployment targetでも
利用できます。

## オプションのAI設定

EMBERの設定画面でOpenRouter API Keyを入力します。KeyはiOS Keychainに
保存され、モデルとOpenAI互換Base URLは変更可能です。Keyがない場合も、
ルールベースのRest Coachを利用できます。

## 公式サイトを起動する

公開サイト：[https://ember-sleep.vercel.app/](https://ember-sleep.vercel.app/)

```bash
cd official-website
pnpm install
pnpm dev
```

`http://localhost:3000`を開きます。

VercelではこのGitリポジトリをインポートし、Root Directoryを
`official-website`に設定してください。`vercel.json`にインストールと
ビルドコマンドが含まれています。

## プロダクト映像を起動する

```bash
cd video
npm install
npm start
```

`npm run build`で最終映像をレンダリングできます。

## ブランドとプロモーション素材

Blue Boxキャラクター、Appアイコン、チェック柄の寝具、スキン素材は
`Ember/Assets.xcassets`にあります。Web用素材は
`official-website/public/assets`にあります。

16:9ポスター、Web機能モジュール、正方形SNS画像、縦型Story/Reel素材は
[`promotional-materials`](promotional-materials)に保存されています。
色、承認済みコピー、用途、参照素材、生成プロンプトは
[`campaign guide`](promotional-materials/campaign-guide.md)を参照してください。

## プロダクトコピー

> 睡眠は身につけられるスキル。EMBERがそのコーチになります。

> トラッカーが伝えるのは昨夜のこと。EMBERが伝えるのは今夜すべきこと。

> あなたのシグナルから、一つの明確な提案へ。

> エビデンスから、より良い夜へ。

## プライバシーと利用範囲

Apple Healthへのアクセスは読み取り専用です。生の睡眠・回復データは
デバイス上で処理され、アカウントとBox Spaceのソーシャルデータには
Supabaseを使用します。EMBERはウェルネスツールであり、医療機器では
ありません。睡眠障害の診断や治療を目的とするものではありません。

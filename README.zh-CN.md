# EMBER

[English](README.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md)

![EMBER — 睡眠是一项可以练习的技能](promotional-materials/poster-01-sleep-is-a-skill.png)

**睡眠是一项可以练习的技能，而 EMBER 是你的教练。**

EMBER 是一款面向 iPhone 的个人睡眠教练。它会综合睡眠数据、日历安排、
昼夜节律、当地天气和卧室环境，为今晚生成一套清晰、个性化的行动计划。

## EMBER 可以做什么

- 生成包含放松、熄灯和起床时间的每晚计划。
- 以只读方式获取 Apple Health 中的睡眠和活动数据。
- 根据早会、晚间活动、旅行、日出时间和气温自动调整计划。
- 提供基于用户真实计划和趋势的流式 AI Rest Coach。
- 未配置 AI 服务时，仍可使用内置规则教练。
- 支持睡眠窗口训练、基于 CBT-I 的睡眠效率和睡前热调节方案。
- 设置起床闹钟和睡前提醒。
- 通过语音识别将 Mind Dump 转换为可编辑文字。
- 通过 Box Space、好友、积分、奖励和 Blue Box 皮肤增加习惯动力。

## 产品体验

### 今晚计划

用一套简单计划告诉你下一步该做什么，以及计划为什么发生变化。

### 日程与每日节律

将日历事件放到个性化昼夜节律曲线上。面对早起或晚间安排时，
EMBER 会提前调整睡眠计划。

### Rest Coach

结合当前计划、睡眠趋势、日历背景和循证知识回答问题。配置 OpenRouter
后，可通过兼容 OpenAI 的接口流式生成回复。

### Rest Lab

通过睡眠窗口训练和 Thermal Wind-Down，把睡眠科学转化为可执行、
可追踪的小步骤。

### Box Space

坚持健康习惯可以获得睡眠积分和 Blue Box 皮肤。Supabase 用于账号、
好友关系、好友请求、奖励和排行榜。

## 技术栈

- **iOS：** Swift 5、SwiftUI、Swift Charts、Swift Concurrency、Combine
- **Apple Framework：** HealthKit、EventKit、CoreLocation、AlarmKit、
  UserNotifications、BackgroundTasks、Speech、AVFoundation、Keychain
- **后端：** Supabase Swift、Supabase Auth、PostgreSQL、RPC
- **AI：** OpenRouter、OpenAI-compatible Chat Completions、SSE 流式输出
- **环境数据：** Open-Meteo API
- **官网：** Next.js 16、React 19、TypeScript、CSS、pnpm、Vercel
- **产品视频：** Remotion 4、React、TypeScript
- **工程工具：** XcodeGen、Swift Package Manager

## 仓库结构

```text
Ember/                    iOS 应用
  AI/                     LLM 客户端和日历分类
  Alarms/                 起床闹钟与提醒
  Algorithms/             节律、睡眠窗口、热调节和计划算法
  Calendar/               EventKit 集成
  Data/                   应用状态、Supabase 和实时数据构建
  Health/                 HealthKit 导入与睡眠指标
  Services/               天气、位置、睡眠气候、缓存和好友服务
  Views/                  SwiftUI 产品界面
  Assets.xcassets/        App 图标、Blue Box 皮肤和品牌素材
official-website/         Next.js 官方网站
video/                    Remotion 产品视频
promotional-materials/    海报、社媒素材和功能模块图
project.yml               XcodeGen 项目配置
```

## 运行 iOS App

建议环境：

- macOS 与 Xcode 16 或更新版本
- iOS 17.6 部署目标
- 建议使用真机测试 HealthKit、位置、麦克风和通知

直接打开项目：

```bash
open Ember.xcodeproj
```

在 Xcode 中选择自己的开发团队和唯一 Bundle Identifier，然后构建
`Ember` target。

修改 `project.yml` 后，可重新生成项目：

```bash
brew install xcodegen
xcodegen generate
```

使用支持 AlarmKit 的 SDK 构建并运行在 iOS 26.1 或更新系统时，可以启用
系统级起床闹钟；其他提醒功能仍支持主部署版本。

## 可选 AI 配置

在 EMBER 设置中填写 OpenRouter API Key。Key 会保存在 iOS Keychain 中，
模型和兼容 OpenAI 的 Base URL 均可修改。未填写 Key 时，应用会继续使用
内置规则版 Rest Coach。

## 运行官方网站

```bash
cd official-website
pnpm install
pnpm dev
```

访问 `http://localhost:3000`。

使用 Vercel 时，导入当前 Git 仓库，并将 Root Directory 设置为
`official-website`。仓库中的 `vercel.json` 已配置安装和构建命令。

## 运行产品视频

```bash
cd video
npm install
npm start
```

使用 `npm run build` 渲染最终视频。

## 品牌与宣传素材

Blue Box 角色、App 图标、格纹床品和皮肤素材来自
`Ember/Assets.xcassets`，网站版本位于
`official-website/public/assets`。

完成的 16:9 海报、官网功能模块、方形社媒图和竖版 Story/Reel 素材位于
[`promotional-materials`](promotional-materials)。配色、正式文案、用途、
源文件和制作提示词记录在
[`campaign guide`](promotional-materials/campaign-guide.md) 中。

## 项目文案

> 睡眠是一项可以练习的技能，而 EMBER 是你的教练。

> 普通追踪器告诉你昨晚发生了什么，EMBER 告诉你今晚该做什么。

> 你的真实信号，汇聚成一条清晰建议。

> 以证据为起点，走向更好的每一个夜晚。

## 隐私与使用范围

Apple Health 权限为只读，原始睡眠和恢复数据在设备本地处理；账号和
Box Space 社交数据使用 Supabase。EMBER 是健康辅助工具，不是医疗器械，
不用于诊断或治疗睡眠障碍。

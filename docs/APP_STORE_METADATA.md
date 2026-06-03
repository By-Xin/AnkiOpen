# App Store / TestFlight 元数据草案

本文档用于准备 AnkiOpen 第一版的 App Store Connect 信息。当前第一版仍是本机离线、development-signed 包；正式 TestFlight/App Store 需要 Apple Developer Program、App Store Connect app record、distribution signing 和上传流程。

## 基本信息

- App name: `潮语 Anki`
- Bundle ID: `com.xinby.AnkiOpen`
- SKU: `chaoyu-anki-ios`
- Primary language: `Simplified Chinese`
- Category: `Education`
- Secondary category: `Reference`
- Age rating: `4+`
- Version: `0.1.0`
- Copyright: `2026 Xin Baiying`

## Subtitle

潮语闪卡、词典与间隔复习

## Promotional Text

为潮语学习设计的开源闪卡 App：支持 CSV 批量导入、单元管理、FSRS 间隔复习、潮语词典查词、音频播放、反馈修正和本机备份。

## Description

潮语 Anki 是一个面向潮语学习的开源 iOS 闪卡 App。第一版聚焦本机离线学习和可维护的语料工作流，适合把 CSV 词表、潮语读音、解释和音频整理成可复习的卡片。

主要功能：

- 笔记本、单元、卡片三级结构，适合按课程、主题或语料批次组织学习内容。
- CSV 批量导入，支持 `front`、`back`、`unit`、音频列、归档状态和潮语词典查词列。
- FSRS-6 风格间隔复习，支持到期学习、全部学习、强制学习和 shuffle。
- 潮语词典查询，展示潮拼、解释和可用音频，并可保存为闪卡。
- 正反两面音频播放，支持导入音频、词典匹配音频和缺音频批量修复。
- 反馈与修正流程，可报告音频不匹配、潮拼/读音错误、释义错误或其他问题。
- JSON 备份与恢复，保留笔记本、单元、卡片、复习进度、反馈、修正记录和音频文件。
- 本机优先：第一版不需要账号，不自动云同步，不包含广告或第三方分析 SDK。

说明：

潮语词典和音频匹配功能会在用户主动使用时请求 CZYZD。DeepSeek 功能仅在用户填写 API Key 并主动使用生僻字建议或词典清洗时启用。所有学习数据默认保存在本机。

## Keywords

潮语,潮汕话,潮州话,闪卡,Anki,FSRS,间隔重复,词典,潮拼,背单词,语言学习,CSV

## Support URL

https://github.com/By-Xin/AnkiOpen

## Marketing URL

https://github.com/By-Xin/AnkiOpen

## Privacy Policy URL

第一版可先使用 GitHub 仓库中的隐私说明文档或 README 隐私段落。正式上架前建议增加一个稳定页面，例如：

https://github.com/By-Xin/AnkiOpen/blob/main/README.md

## TestFlight Beta App Review Notes

This is an offline-first Chaoshan language flashcard app. Testers can create notebooks, import CSV flashcards, study with FSRS-style scheduling, search the CZYZD dictionary, attach or play audio, report card issues, and export JSON backups.

No account is required. The app does not include ads or analytics SDKs. CZYZD dictionary/audio requests happen only when the tester uses dictionary or audio matching features. DeepSeek requests happen only after a tester enters their own API key in Settings.

Suggested test path:

1. Open the app and create a notebook.
2. Import a small CSV with `unit,front,back`.
3. Open Study, reveal a card, and rate it `Good`.
4. Search the dictionary for `你好`, inspect chaopin/definition, and save it as a card.
5. Report a card issue, edit the card from Feedback, and confirm the report is resolved.
6. Create a JSON backup from Settings.

## App Review Notes

No login credentials are required.

Network use:

- CZYZD dictionary and audio lookup: user-triggered dictionary/audio features.
- DeepSeek API: only if the user enters their own API key in Settings and uses rare-glyph suggestions or dictionary cleanup.

The app stores learning data locally with Core Data and stores the DeepSeek API key in Keychain. It does not include third-party analytics SDKs or advertising SDKs.

## Privacy Answers Draft

Use the actual App Store Connect UI wording when filling this in, but first-version behavior should map to:

- Tracking: `No`
- Data linked to user: `No account system in MVP`
- Data used to track users: `No`
- Third-party advertising: `No`
- Third-party analytics SDK: `No`
- User content stored locally: cards, notes, audio, reports, review logs
- Data leaves device only when user explicitly uses:
  - CZYZD dictionary/audio lookup
  - DeepSeek rare-glyph or dictionary cleanup after entering an API key
  - iOS share sheet for CSV/JSON export

`PrivacyInfo.xcprivacy` currently declares:

- `NSPrivacyTracking`: `false`
- `NSPrivacyCollectedDataTypes`: empty
- `NSPrivacyAccessedAPICategoryUserDefaults`: `CA92.1`

## Screenshot Checklist

Prepare iPhone screenshots in Chinese:

1. 首页: dashboard with due cards, notebooks, maintenance links.
2. 笔记本详情: units and card counts.
3. 学习页: front side, answer side, and four rating buttons.
4. 导入页: CSV/audio import and result summary.
5. 潮语词典: chaopin, definition, audio, save-to-notebook action.
6. 缺音频队列 or 维护中心: repair workflow.
7. 反馈页: open/resolved reports and correction workflow.
8. 设置页: backup, DeepSeek, privacy/data, release checklist.

Avoid screenshots containing private API keys, personal notes, or copyrighted dictionary content beyond short examples.

## Release Readiness Notes

- Development IPA is only for registered development devices.
- App Store/TestFlight upload needs distribution signing, App Store Connect app record, and likely `xcodebuild -exportArchive` with App Store distribution options or Xcode Organizer upload.
- Before external TestFlight, run the manual acceptance path in `docs/RELEASE_RUNBOOK.md`.
- Rebuild archive after any source or resource change, then verify `PrivacyInfo.xcprivacy` exists inside the archived app bundle.

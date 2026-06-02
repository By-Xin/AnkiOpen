# 第一版发布与装机 Runbook

本文档记录 AnkiOpen 第一版的本地打包、真机安装、GitHub Release、以及常见设备连接问题排查。

## 当前发布状态

- Release tag: `v0.1.0`
- GitHub Release: https://github.com/By-Xin/AnkiOpen/releases/tag/v0.1.0
- 本地 archive: `build/AnkiOpen-FirstRelease.xcarchive`
- 本地 development IPA: `build/FirstReleaseExport/AnkiOpen.ipa`
- Bundle identifier: `com.xinby.AnkiOpen`
- Development team: `779KR46X3G`

当前 IPA 是 development-signed，只适合已注册或受 Xcode 管理的开发设备。TestFlight 和 App Store 需要付费 Apple Developer Program、App Store Connect app record、distribution signing certificate/profile。

## 每次发版前检查

1. 确认工作区干净：

   ```bash
   git status --short
   ```

2. 跑本地单元测试：

   ```bash
   xcodebuild test \
     -project AnkiOpen.xcodeproj \
     -scheme AnkiOpen \
     -destination 'platform=iOS Simulator,name=iPhone 17' \
     -derivedDataPath /tmp/AnkiOpenDerivedData \
     -only-testing:AnkiOpenTests \
     CODE_SIGNING_ALLOWED=NO
   ```

3. 跑本地 UI 启动 smoke test：

   ```bash
   xcodebuild test \
     -project AnkiOpen.xcodeproj \
     -scheme AnkiOpen \
     -destination 'platform=iOS Simulator,name=iPhone 17' \
     -derivedDataPath /tmp/AnkiOpenDerivedData \
     -only-testing:AnkiOpenUITests \
     CODE_SIGNING_ALLOWED=NO
   ```

4. 确认 GitHub Actions 通过：

   ```bash
   gh run list --repo By-Xin/AnkiOpen --branch main --limit 5
   ```

## 生成本地 Release Archive

```bash
xcodebuild archive \
  -project AnkiOpen.xcodeproj \
  -scheme AnkiOpen \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$PWD/build/AnkiOpen-FirstRelease.xcarchive" \
  DEVELOPMENT_TEAM=779KR46X3G \
  CODE_SIGN_STYLE=Automatic
```

如果 archive validation 出现方向相关警告，确认 `AnkiOpen/Info.plist` 包含 full-screen portrait metadata。

## 导出 Development IPA

`build/ExportOptions-development.plist` 是本地文件，不提交到 Git。它至少需要包含：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>development</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>779KR46X3G</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>compileBitcode</key>
  <false/>
</dict>
</plist>
```

导出：

```bash
xcodebuild -exportArchive \
  -archivePath "$PWD/build/AnkiOpen-FirstRelease.xcarchive" \
  -exportPath "$PWD/build/FirstReleaseExport" \
  -exportOptionsPlist "$PWD/build/ExportOptions-development.plist"
```

Xcode 可能提示 `development` export method deprecated。第一版本地装机可以接受；后续上 TestFlight 时应改为 App Store Connect 分发流程。

## 真机安装和启动

先确认设备可用：

```bash
xcrun devicectl list devices
```

设备状态必须是 `available`。如果显示 `unavailable`，先看下一节排查。

构建真机 `.app`：

```bash
xcodebuild build \
  -project AnkiOpen.xcodeproj \
  -scheme AnkiOpen \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/AnkiOpenDeviceDerivedData \
  DEVELOPMENT_TEAM=779KR46X3G \
  CODE_SIGN_STYLE=Automatic
```

安装到设备，把 `DEVICE_ID` 换成 `devicectl list devices` 看到的 identifier：

```bash
xcrun devicectl device install app \
  --device DEVICE_ID \
  /private/tmp/AnkiOpenDeviceDerivedData/Build/Products/Debug-iphoneos/AnkiOpen.app
```

启动：

```bash
xcrun devicectl device process launch \
  --device DEVICE_ID \
  --terminate-existing \
  com.xinby.AnkiOpen
```

## 设备显示 unavailable 时

按顺序处理：

1. 解锁 iPhone，并保持屏幕亮着。
2. 使用 USB 线重新连接 Mac。
3. iPhone 上出现信任弹窗时选择信任，并输入锁屏密码。
4. 确认 iPhone 已开启 Developer Mode：`设置 -> 隐私与安全性 -> 开发者模式`。
5. 打开 Xcode 的 `Window -> Devices and Simulators`，等待设备完成配对或符号处理。
6. 重新执行：

   ```bash
   xcrun devicectl list devices
   ```

只有设备变成 `available` 后，CLI 安装和启动才可靠。

## 更新 GitHub Release

正常发布：

```bash
git push origin main
git tag -f -a v0.1.0 -m "First MVP release"
git push origin v0.1.0 --force
```

确认 tag 与 `HEAD` 一致：

```bash
git rev-parse HEAD
git rev-parse v0.1.0^{}
```

确认 Release：

```bash
gh release view v0.1.0 \
  --repo By-Xin/AnkiOpen \
  --json tagName,targetCommitish,url,isDraft,isPrerelease,name
```

## 第一版手动验收

安装到手机后，至少过一遍：

1. 打开 App，确认中文首页正常显示。
2. 导入 `front,back,unit` CSV，确认笔记本、单元、卡片都出现。
3. 进入学习，翻面并选择 `Good`，确认卡片离开当前到期队列。
4. 查询一个潮语词典词条，确认看到 `潮拼`、`解释`，有音频时能播放。
5. 对一张卡提交反馈，再从反馈页打开并修正，确认反馈可解决。
6. 做一次 JSON backup export。
7. 关闭 App 后重开，确认数据仍存在。

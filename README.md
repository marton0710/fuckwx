# 企业微信·本地版 — iOS

根据提供的 Android 本地演示 APK，实现相同交互逻辑的原生 SwiftUI 应用。
最低系统 **iOS 18.0**，适配 iPhone，主要在 **iPhone 16 / iPhone 16 Pro Max** 模拟器验证。

## 功能范围

- 消息、文档、通讯录、工作台、我：五个主页，默认进入「我」。
- 个人资料、头像、两个群名称/头像、35 个成员名称/头像、部门设置均保存在本机。
- 本地文字聊天、表情、收藏提示；聊天仅保留在当前进程内，重启清空，与 APK 一致。
- 工作台 16 组、75 个入口，点击后模拟两秒加载超时，可重试。
- 文档及其他未接入功能显示演示说明。没有登录、真实消息收发或学校服务接口。

## 在 Windows 上取得 IPA

代码推送至 `main` 或手动运行 **Actions → Build iOS unsigned IPA → Run workflow**。
流程使用 GitHub 的 macOS runner 和 Xcode 16.4，先在两个 iPhone 16 系列模拟器运行 UI 测试，
再构建真机 arm64 应用，打包并验证 `Payload/LocalDemo.app`。

构建成功后，在该次运行的 Artifacts 下载 **LocalDemo-iOS18-unsigned**：

- `LocalDemo-unsigned.ipa`
- `SHA256SUMS.txt`

这是未签名 IPA，需要自行签名后安装，不需要在仓库配置签名证书或 Apple 账号。
默认 Bundle ID 为 `com.marton.localdemo`，如需修改，在 `scripts/generate_project.py` 修改后重新生成。
测试截图、`.xcresult` 和构建日志位于 **iOS-test-results** artifact。

## 开发和验证

项目不依赖 CocoaPods、Swift Package 或 XcodeGen。

```powershell
python scripts/generate_project.py
python scripts/validate_project.py
```

在 Mac 上打开 `ios/LocalDemo.xcodeproj`，或者：

```bash
bash scripts/test_ios.sh
bash scripts/build_ipa.sh
```

项目文件由脚本生成并提交；增加 Swift 文件后需要重新生成。
UI 测试通过 `--ui-testing` 使用独立资料目录，不影响正常使用数据。

CI 运行环境参考：[GitHub macOS 15 runner](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md)。

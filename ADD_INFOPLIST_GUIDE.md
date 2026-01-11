# 在 Xcode 中添加 Info.plist 文件 - 修复 Google Sign-In 崩溃

## 问题原因

Google Sign-In 需要在 Info.plist 中配置 URL Scheme，但当前的自动生成方式无法正确添加这个配置。

## 解决方案

已经为您创建好了正确的 Info.plist 文件：`Earthlord/Info.plist`

现在只需要在 Xcode 中配置项目使用这个文件。

## 操作步骤（大约 2 分钟）

### 步骤 1：在 Xcode 中打开项目
1. 打开 Xcode
2. 打开 `Earthlord.xcodeproj`

### 步骤 2：选择项目和 Target
1. 点击左侧项目导航器中的 "Earthlord" 项目（蓝色图标）
2. 在中间区域确保选中了 "Earthlord" target

### 步骤 3：进入 Build Settings
1. 点击顶部的 "Build Settings" 标签
2. 在搜索框中输入 "info"

### 步骤 4：配置 Info.plist 文件路径
1. 找到 "Packaging" 部分下的两个设置：
   - **"Info.plist File"** (INFOPLIST_FILE)
   - **"Generate Info.plist File"** (GENERATE_INFOPLIST_FILE)

2. 修改这两个设置：
   - **"Generate Info.plist File"**: 改为 **NO**（取消勾选）
   - **"Info.plist File"**: 改为 **Earthlord/Info.plist**

3. 确保在 **Debug** 和 **Release** 两个配置中都进行了修改

### 步骤 5：清理并重新构建
1. 菜单栏：**Product** → **Clean Build Folder**（或按 Shift + Command + K）
2. 菜单栏：**Product** → **Run**（或按 Command + R）

## 验证结果

构建成功后，应用应该能够正常启动，点击"使用 Google 登录"不再崩溃。

## 截图说明

在 Build Settings 中，配置应该看起来像这样：

```
Generate Info.plist File = NO
Info.plist File = Earthlord/Info.plist
```

## 如果还是遇到问题

1. **检查文件路径**：
   - 确保 `Earthlord/Info.plist` 文件存在
   - 路径是相对于项目根目录的

2. **检查配置生效**：
   - 构建后检查生成的 app 包中的 Info.plist
   - 应该包含 `CFBundleURLTypes` 配置

3. **重启 Xcode**：
   - 有时候需要重启 Xcode 让配置生效

## Info.plist 文件内容

文件位置：`/Users/quq/Desktop/Earthlord_1224/Earthlord/Info.plist`

包含的配置：
- ✅ CFBundleURLTypes（Google Sign-In URL Scheme）
  - URL Scheme: `com.googleusercontent.apps.744447936656-34vtvpphasc56s6m2jo9f6uroh2df046`
  - Role: Editor

---

**注意**：这个方法比脚本修改更安全可靠，且是 Apple 推荐的标准做法。

# 修复 Google Sign-In 崩溃问题

## 问题原因

应用在启动时崩溃，因为 Google Sign-In SDK 需要在 Info.plist 中配置 URL Scheme，但当前配置缺失。

崩溃日志显示：
```
GIDSignIn.m:620 - signInWithOptions
NSException: 缺少 CFBundleURLTypes 配置
```

## 解决方案

需要在 Xcode 项目配置中添加 Google Sign-In 的 URL Scheme。

### 方法 1：通过 Xcode GUI 添加（推荐）

1. **打开项目**
   - 在 Xcode 中打开 `Earthlord.xcodeproj`

2. **选择 Target**
   - 点击左侧项目导航器中的 "Earthlord" 项目
   - 在中间区域选择 "Earthlord" target

3. **进入 Info 标签页**
   - 点击顶部的 "Info" 标签

4. **添加 URL Types**
   - 向下滚动找到 "URL Types" 部分
   - 点击 "+" 按钮添加新的 URL Type
   - 填写以下信息：
     - **Identifier**: `com.google.GIDClientID`
     - **URL Schemes**: `com.googleusercontent.apps.744447936656-34vtvpphasc56s6m2jo9f6uroh2df046`
     - **Role**: `Editor`（下拉选择）

5. **保存并重新构建**
   - Command + B 重新构建项目
   - Command + R 运行应用

### 方法 2：手动编辑 project.pbxproj（仅适用于熟悉 Xcode 项目文件的用户）

如果您熟悉 Xcode 项目文件格式，可以手动编辑：

1. 关闭 Xcode
2. 找到以下两处配置（在 `Debug` 和 `Release` 配置中）：
   ```
   ENABLE_USER_SELECTED_FILES = readonly;
   GENERATE_INFOPLIST_FILE = YES;
   ```
3. 在这两行之间添加：
   ```
   INFOPLIST_KEY_CFBundleURLTypes = (
       {
           CFBundleTypeRole = Editor;
           CFBundleURLSchemes = (
               "com.googleusercontent.apps.744447936656-34vtvpphasc56s6m2jo9f6uroh2df046",
           );
       },
   );
   ```
4. 保存并重新打开 Xcode

## 验证

添加 URL Scheme 后，可以通过以下方式验证：

1. **构建项目**
   ```bash
   xcodebuild -scheme Earthlord -sdk iphonesimulator build
   ```

2. **检查生成的 Info.plist**
   ```bash
   plutil -p ~/Library/Developer/Xcode/DerivedData/Earthlord-*/Build/Products/Debug-iphonesimulator/Earthlord.app/Info.plist | grep -A 10 CFBundleURL
   ```

   应该能看到：
   ```
   "CFBundleURLTypes" => [
     0 => {
       "CFBundleTypeRole" => "Editor"
       "CFBundleURLSchemes" => [
         0 => "com.googleusercontent.apps.744447936656-34vtvpphasc56s6m2jo9f6uroh2df046"
       ]
     }
   ]
   ```

3. **运行应用**
   - 应用应该能正常启动，不再崩溃
   - Google 登录按钮可以正常点击

## 临时绕过方案（仅用于测试探索功能）

如果您暂时想跳过 Google 登录，直接测试探索功能：

1. 在 AuthView.swift 中找到 Google 登录按钮
2. 临时注释掉或隐藏该按钮
3. 使用其他登录方式（如果有）
4. 或者直接在代码中模拟登录状态进行测试

## 技术说明

### 为什么需要URL Scheme？

Google Sign-In SDK 使用 OAuth 2.0 流程，需要：
1. 应用跳转到浏览器进行 Google 认证
2. 认证完成后，浏览器通过 URL Scheme 回调到应用
3. URL Scheme 格式：`com.googleusercontent.apps.[CLIENT_ID]`

没有这个配置，SDK 会在初始化时抛出异常。

### Client ID

当前使用的 Google OAuth Client ID：
```
744447936656-34vtvpphasc56s6m2jo9f6uroh2df046.apps.googleusercontent.com
```

对应的 URL Scheme：
```
com.googleusercontent.apps.744447936656-34vtvpphasc56s6m2jo9f6uroh2df046
```

## 相关文件

- 崩溃日志：`~/Library/Logs/DiagnosticReports/Earthlord-*.ips`
- AuthManager：`Earthlord/AuthManager.swift:339`
- 项目配置：`Earthlord.xcodeproj/project.pbxproj`

## 后续步骤

配置完成后：
1. ✅ 重新构建项目
2. ✅ 运行应用验证不崩溃
3. ✅ 测试探索模块功能（地图、POI 列表、背包等）
4. ✅ （可选）测试 Google 登录功能

---

**创建时间**: 2026-01-11
**问题类型**: Google Sign-In 配置缺失
**影响范围**: 应用启动崩溃
**解决状态**: 等待手动配置

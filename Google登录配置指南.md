# Google 登录配置指南

## 已完成的实现

✅ 所有代码已经实现完成，构建成功！

### 1. AuthManager.swift
- 导入 GoogleSignIn SDK
- 实现了完整的 `signInWithGoogle()` 方法
- 添加了详细的中文调试日志，包括：
  - 🔵 获取根视图控制器
  - 🔵 配置 Google Sign In
  - 🔵 启动 Google 登录界面
  - 🔵 获取 Google ID Token
  - 🔵 使用 Google ID Token 登录 Supabase
  - 🔵 更新认证状态
  - ✅ 各步骤成功日志
  - ❌ 错误日志

### 2. AuthView.swift
- Google 登录按钮已更新，点击时调用 `authManager.signInWithGoogle()`

### 3. EarthlordApp.swift
- 添加了 `.onOpenURL` 处理器来接收 Google OAuth 回调
- 包含中文日志：
  - 🔗 收到 URL callback
  - ✅ Google Sign In URL callback 已处理

## 需要在 Xcode 中手动配置的最后一步

### 配置 URL Schemes（必须完成才能使用 Google 登录）

1. 在 Xcode 中打开 `Earthlord.xcodeproj`
2. 选择项目导航器中的 **Earthlord** 项目（蓝色图标）
3. 选择 **TARGETS** 下的 **Earthlord**
4. 点击顶部的 **Info** 标签页
5. 找到 **URL Types** 部分（如果没有，点击 + 添加一个）
6. 点击 + 添加新的 URL Type
7. 填写以下信息：
   - **Identifier**: `com.googleusercontent.apps.744447936656-34vtvpphasc56s6m2jo9f6uroh2df046`
   - **URL Schemes**: `com.googleusercontent.apps.744447936656-34vtvpphasc56s6m2jo9f6uroh2df046`
   - **Role**: Editor

### URL Scheme 格式说明
您的 Client ID 是：`744447936656-34vtvpphasc56s6m2jo9f6uroh2df046.apps.googleusercontent.com`
URL Scheme 是：`com.googleusercontent.apps.744447936656-34vtvpphasc56s6m2jo9f6uroh2df046`

（去掉 `.apps.googleusercontent.com` 后缀，前面加上 `com.googleusercontent.apps.`）

## 测试 Google 登录

配置完 URL Schemes 后：

1. 运行 App（在真实设备或模拟器上）
2. 在登录页面点击 "使用 Google 登录" 按钮
3. 查看 Xcode 控制台的日志输出，您会看到：
   ```
   🔵 开始 Google 登录流程
   🔵 步骤 1: 获取根视图控制器
   🔵 步骤 2: 配置 Google Sign In
   ✅ Google Sign In 配置完成，Client ID: 744447936656-34vtvpphasc56s6m2jo9f6uroh2df046.apps.googleusercontent.com
   🔵 步骤 3: 启动 Google 登录界面
   ```
4. 在弹出的 Google 登录界面选择账号
5. 授权后会看到：
   ```
   ✅ Google 登录成功
   🔵 步骤 4: 获取 Google ID Token
   ✅ 成功获取 ID Token: ...
   🔵 步骤 5: 使用 Google ID Token 登录 Supabase
   ✅ Supabase 登录成功
   🔵 步骤 6: 更新认证状态
   ✅ Google 登录流程完成，用户 ID: ...
   🔗 收到 URL callback: ...
   ✅ Google Sign In URL callback 已处理
   ```
6. 登录成功后自动跳转到主界面

## 可能的问题排查

### 问题 1: 点击按钮没有反应
- 检查 Xcode 控制台是否有日志输出
- 确认 URL Schemes 配置正确

### 问题 2: Google 登录界面闪退或无法跳转
- 确认 Supabase 后台的 Google Provider 配置正确
- 确认 Authorized Client IDs 包含您的 iOS Client ID
- 确认 Skip nonce check 已开启

### 问题 3: Supabase 登录失败
- 查看控制台错误日志
- 检查 Supabase 后台 Google Provider 设置
- 确认使用的是正确的 Web Client ID（在 Supabase 后台配置的那个）

## 代码位置参考

- Google 登录实现：`Earthlord/AuthManager.swift:315-395`
- Google 登录按钮：`Earthlord/Views/AuthView.swift:141-157`
- URL callback 处理：`Earthlord/EarthlordApp.swift:16-21`

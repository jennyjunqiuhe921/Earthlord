//
//  AuthManager.swift
//  Earthlord
//
//  Created by Claude Code on 2025/12/26.
//

import SwiftUI
import Combine
import Supabase

/// 认证管理器 - 处理用户注册、登录、找回密码等认证流程
///
/// 流程说明：
/// - 注册：发验证码 → 验证（此时已登录但没密码）→ 强制设置密码 → 完成
/// - 登录：邮箱 + 密码（直接登录）
/// - 找回密码：发验证码 → 验证（此时已登录）→ 设置新密码 → 完成
@MainActor
class AuthManager: ObservableObject {

    // MARK: - Published Properties

    /// 用户是否已完全认证（已登录且完成所有必要流程）
    @Published var isAuthenticated: Bool = false

    /// 是否需要设置密码（OTP 验证后需要设置密码）
    @Published var needsPasswordSetup: Bool = false

    /// 当前登录用户
    @Published var currentUser: User? = nil

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误消息
    @Published var errorMessage: String? = nil

    /// OTP 是否已发送
    @Published var otpSent: Bool = false

    /// OTP 是否已验证（验证码已验证，等待设置密码）
    @Published var otpVerified: Bool = false

    // MARK: - Private Properties

    /// Supabase 客户端实例
    private let supabase: SupabaseClient

    /// 认证状态变化监听器的取消令牌
    private var authStateTask: Task<Void, Never>?

    // MARK: - Initialization

    init(supabaseClient: SupabaseClient? = nil) {
        // 如果没有传入客户端，创建默认实例
        if let client = supabaseClient {
            self.supabase = client
        } else {
            // 使用默认配置创建 Supabase 客户端
            self.supabase = SupabaseClient(
                supabaseURL: URL(string: "https://acnriuoexalqvckiuvgr.supabase.co")!,
                supabaseKey: "sb_publishable_ddDdaU8v_cxisWA6TiHDuA_BHAdLp-R"
            )
        }

        // 启动认证状态监听
        setupAuthStateListener()
    }

    deinit {
        // 取消监听器
        authStateTask?.cancel()
    }

    // MARK: - 注册流程

    /// 发送注册验证码
    /// - Parameter email: 用户邮箱
    func sendRegisterOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            // 调用 Supabase signInWithOTP，允许创建新用户
            try await supabase.auth.signInWithOTP(
                email: email,
                shouldCreateUser: true
            )

            // 成功发送
            otpSent = true
            errorMessage = nil

        } catch {
            // 发送失败
            errorMessage = "发送验证码失败: \(error.localizedDescription)"
            otpSent = false
        }

        isLoading = false
    }

    /// 验证注册 OTP
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    ///
    /// 注意：验证成功后用户已登录，但需要设置密码才能完成注册
    func verifyRegisterOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 验证 OTP，type 为 .email
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .email
            )

            // 验证成功：用户已登录，但需要设置密码
            otpVerified = true
            needsPasswordSetup = true
            currentUser = session.user

            // 注意：此时 isAuthenticated 保持 false，等待设置密码
            isAuthenticated = false
            errorMessage = nil

        } catch {
            // 验证失败
            errorMessage = "验证码错误或已过期: \(error.localizedDescription)"
            otpVerified = false
        }

        isLoading = false
    }

    /// 完成注册（设置密码）
    /// - Parameter password: 用户密码
    ///
    /// 此方法在 OTP 验证成功后调用，用于设置用户密码并完成注册流程
    func completeRegistration(password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            let updatedUser = try await supabase.auth.update(
                user: UserAttributes(password: password)
            )

            // 密码设置成功，完成注册
            currentUser = updatedUser
            needsPasswordSetup = false
            isAuthenticated = true
            otpVerified = false
            otpSent = false
            errorMessage = nil

        } catch {
            // 密码设置失败
            errorMessage = "设置密码失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 登录流程

    /// 使用邮箱和密码登录
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - password: 用户密码
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 使用邮箱和密码登录
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            // 登录成功
            currentUser = session.user
            isAuthenticated = true
            needsPasswordSetup = false
            errorMessage = nil

        } catch {
            // 登录失败
            errorMessage = "登录失败: \(error.localizedDescription)"
            isAuthenticated = false
        }

        isLoading = false
    }

    // MARK: - 找回密码流程

    /// 发送密码重置验证码
    /// - Parameter email: 用户邮箱
    ///
    /// 这会触发 Supabase 的 Reset Password 邮件模板
    func sendResetOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            // 发送密码重置邮件
            try await supabase.auth.resetPasswordForEmail(email)

            // 发送成功
            otpSent = true
            errorMessage = nil

        } catch {
            // 发送失败
            errorMessage = "发送重置验证码失败: \(error.localizedDescription)"
            otpSent = false
        }

        isLoading = false
    }

    /// 验证密码重置 OTP
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    ///
    /// ⚠️ 注意：type 必须是 .recovery，不是 .email
    func verifyResetOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 验证 OTP，type 为 .recovery（密码重置类型）
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .recovery
            )

            // 验证成功：用户已登录，需要设置新密码
            otpVerified = true
            needsPasswordSetup = true
            currentUser = session.user

            // 等待设置新密码
            isAuthenticated = false
            errorMessage = nil

        } catch {
            // 验证失败
            errorMessage = "验证码错误或已过期: \(error.localizedDescription)"
            otpVerified = false
        }

        isLoading = false
    }

    /// 重置密码（设置新密码）
    /// - Parameter newPassword: 新密码
    ///
    /// 此方法在密码重置 OTP 验证成功后调用
    func resetPassword(newPassword: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            let updatedUser = try await supabase.auth.update(
                user: UserAttributes(password: newPassword)
            )

            // 密码重置成功
            currentUser = updatedUser
            needsPasswordSetup = false
            isAuthenticated = true
            otpVerified = false
            otpSent = false
            errorMessage = nil

        } catch {
            // 密码重置失败
            errorMessage = "重置密码失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 第三方登录（预留）

    /// Apple 登录
    /// TODO: 实现 Apple Sign In 集成
    func signInWithApple() async {
        isLoading = true
        errorMessage = nil

        // TODO: 实现 Apple Sign In 流程
        // 1. 使用 AuthenticationServices 获取 Apple ID Credential
        // 2. 调用 supabase.auth.signInWithIdToken(...)
        // 3. 更新认证状态

        errorMessage = "Apple 登录功能即将推出"
        isLoading = false
    }

    /// Google 登录
    /// TODO: 实现 Google Sign In 集成
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil

        // TODO: 实现 Google Sign In 流程
        // 1. 使用 GoogleSignIn SDK 获取 ID Token
        // 2. 调用 supabase.auth.signInWithIdToken(...)
        // 3. 更新认证状态

        errorMessage = "Google 登录功能即将推出"
        isLoading = false
    }

    // MARK: - 登出

    /// 登出当前用户
    func signOut() async {
        isLoading = true
        errorMessage = nil

        do {
            // 调用 Supabase 登出
            try await supabase.auth.signOut()

            // 清空所有状态
            currentUser = nil
            isAuthenticated = false
            needsPasswordSetup = false
            otpSent = false
            otpVerified = false
            errorMessage = nil

        } catch {
            // 登出失败
            errorMessage = "登出失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 会话管理

    /// 检查当前会话状态
    ///
    /// 用于应用启动时检查用户是否已登录
    func checkSession() async {
        isLoading = true

        do {
            // 获取当前会话
            let session = try await supabase.auth.session

            // 会话存在，用户已登录
            currentUser = session.user

            // 检查用户是否需要设置密码
            // 注意：这里需要根据实际业务逻辑判断
            // 可以通过检查 user metadata 或其他方式判断

            // 暂时假设有会话就是完全认证
            isAuthenticated = true
            needsPasswordSetup = false

        } catch {
            // 没有有效会话，用户未登录
            currentUser = nil
            isAuthenticated = false
            needsPasswordSetup = false
        }

        isLoading = false
    }

    // MARK: - 认证状态监听

    /// 设置认证状态变化监听器
    ///
    /// 监听 Supabase 的认证事件（登录、登出、token刷新等），自动更新认证状态
    private func setupAuthStateListener() {
        authStateTask = Task { @MainActor in
            // 监听认证状态变化流
            for await (event, session) in supabase.auth.authStateChanges {
                print("🔐 Auth state changed: \(event)")

                switch event {
                case .signedIn, .tokenRefreshed, .initialSession:
                    // 用户已登录或 token 已刷新
                    if let session = session {
                        currentUser = session.user

                        // 检查是否是 OTP 验证后但未设置密码的状态
                        // 如果当前处于注册流程中，不要立即标记为已认证
                        if !otpVerified && !needsPasswordSetup {
                            isAuthenticated = true
                        }
                    }

                case .signedOut:
                    // 用户已登出
                    currentUser = nil
                    isAuthenticated = false
                    needsPasswordSetup = false
                    otpSent = false
                    otpVerified = false
                    errorMessage = nil

                case .passwordRecovery:
                    // 密码恢复流程（用户点击了重置密码邮件中的链接）
                    if let session = session {
                        currentUser = session.user
                        needsPasswordSetup = true
                        otpVerified = true
                        isAuthenticated = false
                    }

                case .userUpdated:
                    // 用户信息已更新（如密码、邮箱等）
                    if let session = session {
                        currentUser = session.user
                    }

                default:
                    break
                }
            }
        }
    }

    // MARK: - 辅助方法

    /// 清空错误消息
    func clearError() {
        errorMessage = nil
    }

    /// 重置 OTP 状态（用于重新发送验证码）
    func resetOTPState() {
        otpSent = false
        otpVerified = false
        errorMessage = nil
    }
}

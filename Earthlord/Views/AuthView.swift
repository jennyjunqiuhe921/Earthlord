//
//  AuthView.swift
//  Earthlord
//
//  Created by Claude Code on 2025/12/26.
//

import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var authManager: AuthManager

    // Tab 选择
    @State private var selectedTab: AuthTab = .login

    // 登录表单
    @State private var loginEmail = ""
    @State private var loginPassword = ""

    // 注册表单
    @State private var registerEmail = ""
    @State private var registerOTP = ""
    @State private var registerPassword = ""
    @State private var registerConfirmPassword = ""
    @State private var registerStep: RegisterStep = .email
    @State private var resendCountdown = 0

    // 忘记密码弹窗
    @State private var showForgotPassword = false
    @State private var forgotEmail = ""
    @State private var forgotOTP = ""
    @State private var forgotNewPassword = ""
    @State private var forgotConfirmPassword = ""
    @State private var forgotStep: ForgotPasswordStep = .email
    @State private var forgotResendCountdown = 0

    // Toast 提示
    @State private var showToast = false
    @State private var toastMessage = ""

    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    Color(red: 0.1, green: 0.1, blue: 0.2)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 30) {
                    // 顶部 Logo 和标题
                    VStack(spacing: 16) {
                        Image(systemName: "globe.americas.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.orange)

                        Text("地球新主")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 60)

                    // Tab 切换
                    HStack(spacing: 0) {
                        TabButton(title: "登录", isSelected: selectedTab == .login) {
                            withAnimation {
                                selectedTab = .login
                                resetForms()
                            }
                        }

                        TabButton(title: "注册", isSelected: selectedTab == .register) {
                            withAnimation {
                                selectedTab = .register
                                resetForms()
                            }
                        }
                    }
                    .padding(.horizontal, 40)

                    // 内容区域
                    VStack(spacing: 20) {
                        if selectedTab == .login {
                            loginView
                        } else {
                            registerView
                        }
                    }
                    .padding(.horizontal, 30)

                    // 错误提示
                    if let error = authManager.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 30)
                    }

                    // 分隔线
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray.opacity(0.3))

                        Text("或者使用以下方式登录")
                            .font(.caption)
                            .foregroundColor(.gray)

                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray.opacity(0.3))
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 20)

                    // 第三方登录按钮
                    VStack(spacing: 12) {
                        // Apple 登录
                        Button(action: {
                            showToastMessage("Apple 登录即将开放")
                        }) {
                            HStack {
                                Image(systemName: "apple.logo")
                                    .font(.title3)
                                Text("使用 Apple 登录")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .cornerRadius(10)
                        }

                        // Google 登录
                        Button(action: {
                            Task {
                                await authManager.signInWithGoogle()
                            }
                        }) {
                            HStack {
                                Image(systemName: "g.circle.fill")
                                    .font(.title3)
                                Text("使用 Google 登录")
                                    .font(.headline)
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 40)
                }
            }

            // 加载指示器
            if authManager.isLoading {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                }
            }

            // Toast 提示
            if showToast {
                VStack {
                    Spacer()
                    Text(toastMessage)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(10)
                        .padding(.bottom, 50)
                }
                .transition(.move(edge: .bottom))
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            forgotPasswordView
        }
        .onReceive(authManager.$otpVerified) { verified in
            // 注册流程：OTP 验证成功后跳转到设置密码步骤
            if selectedTab == .register && verified {
                registerStep = .password
            }
        }
    }

    // MARK: - 登录视图

    private var loginView: some View {
        VStack(spacing: 16) {
            // 邮箱输入框
            CustomTextField(
                icon: "envelope.fill",
                placeholder: "邮箱",
                text: $loginEmail,
                keyboardType: .emailAddress
            )

            // 密码输入框
            CustomSecureField(
                icon: "lock.fill",
                placeholder: "密码",
                text: $loginPassword
            )

            // 忘记密码链接
            HStack {
                Spacer()
                Button(action: {
                    showForgotPassword = true
                    forgotEmail = loginEmail
                }) {
                    Text("忘记密码？")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            // 登录按钮
            Button(action: {
                Task {
                    await authManager.signIn(email: loginEmail, password: loginPassword)
                }
            }) {
                Text("登录")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(10)
            }
            .disabled(loginEmail.isEmpty || loginPassword.isEmpty)
            .opacity(loginEmail.isEmpty || loginPassword.isEmpty ? 0.6 : 1)
            .padding(.top, 10)
        }
    }

    // MARK: - 注册视图

    private var registerView: some View {
        VStack(spacing: 16) {
            // 步骤指示器
            StepIndicator(currentStep: registerStep.rawValue, totalSteps: 3)

            switch registerStep {
            case .email:
                registerEmailStep
            case .otp:
                registerOTPStep
            case .password:
                registerPasswordStep
            }
        }
    }

    // 注册 - 第一步：邮箱
    private var registerEmailStep: some View {
        VStack(spacing: 16) {
            Text("输入您的邮箱")
                .font(.headline)
                .foregroundColor(.white)

            CustomTextField(
                icon: "envelope.fill",
                placeholder: "邮箱",
                text: $registerEmail,
                keyboardType: .emailAddress
            )

            Button(action: {
                Task {
                    await authManager.sendRegisterOTP(email: registerEmail)
                    if authManager.otpSent {
                        registerStep = .otp
                        startResendCountdown()
                    }
                }
            }) {
                Text("发送验证码")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(10)
            }
            .disabled(registerEmail.isEmpty || !isValidEmail(registerEmail))
            .opacity(registerEmail.isEmpty || !isValidEmail(registerEmail) ? 0.6 : 1)
        }
    }

    // 注册 - 第二步：OTP
    private var registerOTPStep: some View {
        VStack(spacing: 16) {
            Text("输入验证码")
                .font(.headline)
                .foregroundColor(.white)

            Text("验证码已发送至 \(registerEmail)")
                .font(.caption)
                .foregroundColor(.gray)

            // 6位验证码输入
            OTPInputView(otp: $registerOTP)

            Button(action: {
                Task {
                    await authManager.verifyRegisterOTP(email: registerEmail, code: registerOTP)
                    // 验证成功后自动跳转到密码设置（由 onReceive 处理）
                }
            }) {
                Text("验证")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(10)
            }
            .disabled(registerOTP.count != 6)
            .opacity(registerOTP.count != 6 ? 0.6 : 1)

            // 重发倒计时
            if resendCountdown > 0 {
                Text("重新发送 (\(resendCountdown)s)")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                Button(action: {
                    Task {
                        await authManager.sendRegisterOTP(email: registerEmail)
                        if authManager.otpSent {
                            startResendCountdown()
                        }
                    }
                }) {
                    Text("重新发送验证码")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
    }

    // 注册 - 第三步：设置密码
    private var registerPasswordStep: some View {
        VStack(spacing: 16) {
            Text("设置密码")
                .font(.headline)
                .foregroundColor(.white)

            Text("请设置您的账户密码")
                .font(.caption)
                .foregroundColor(.gray)

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "密码（至少6位）",
                text: $registerPassword
            )

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "确认密码",
                text: $registerConfirmPassword
            )

            if !registerConfirmPassword.isEmpty && registerPassword != registerConfirmPassword {
                Text("两次密码不一致")
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Button(action: {
                Task {
                    await authManager.completeRegistration(password: registerPassword)
                    // 注册成功后 isAuthenticated = true，自动跳转主页
                }
            }) {
                Text("完成注册")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(10)
            }
            .disabled(!isValidPassword())
            .opacity(isValidPassword() ? 1 : 0.6)
        }
    }

    // MARK: - 忘记密码视图

    private var forgotPasswordView: some View {
        NavigationView {
            ZStack {
                Color.black.opacity(0.9)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        switch forgotStep {
                        case .email:
                            forgotPasswordEmailStep
                        case .otp:
                            forgotPasswordOTPStep
                        case .password:
                            forgotPasswordNewPasswordStep
                        }
                    }
                    .padding(30)
                }

                if authManager.isLoading {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()

                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                    }
                }
            }
            .navigationTitle("找回密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        showForgotPassword = false
                        resetForgotPasswordForm()
                    }
                    .foregroundColor(.orange)
                }
            }
        }
    }

    // 忘记密码 - 第一步：邮箱
    private var forgotPasswordEmailStep: some View {
        VStack(spacing: 16) {
            Text("输入您的注册邮箱")
                .font(.headline)
                .foregroundColor(.white)

            CustomTextField(
                icon: "envelope.fill",
                placeholder: "邮箱",
                text: $forgotEmail,
                keyboardType: .emailAddress
            )

            if let error = authManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Button(action: {
                Task {
                    await authManager.sendResetOTP(email: forgotEmail)
                    if authManager.otpSent {
                        forgotStep = .otp
                        startForgotResendCountdown()
                    }
                }
            }) {
                Text("发送验证码")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(10)
            }
            .disabled(forgotEmail.isEmpty || !isValidEmail(forgotEmail))
            .opacity(forgotEmail.isEmpty || !isValidEmail(forgotEmail) ? 0.6 : 1)
        }
    }

    // 忘记密码 - 第二步：验证OTP
    private var forgotPasswordOTPStep: some View {
        VStack(spacing: 16) {
            Text("输入验证码")
                .font(.headline)
                .foregroundColor(.white)

            Text("验证码已发送至 \(forgotEmail)")
                .font(.caption)
                .foregroundColor(.gray)

            OTPInputView(otp: $forgotOTP)

            if let error = authManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Button(action: {
                Task {
                    await authManager.verifyResetOTP(email: forgotEmail, code: forgotOTP)
                    if authManager.otpVerified {
                        forgotStep = .password
                    }
                }
            }) {
                Text("验证")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(10)
            }
            .disabled(forgotOTP.count != 6)
            .opacity(forgotOTP.count != 6 ? 0.6 : 1)

            if forgotResendCountdown > 0 {
                Text("重新发送 (\(forgotResendCountdown)s)")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                Button(action: {
                    Task {
                        await authManager.sendResetOTP(email: forgotEmail)
                        if authManager.otpSent {
                            startForgotResendCountdown()
                        }
                    }
                }) {
                    Text("重新发送验证码")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
    }

    // 忘记密码 - 第三步：设置新密码
    private var forgotPasswordNewPasswordStep: some View {
        VStack(spacing: 16) {
            Text("设置新密码")
                .font(.headline)
                .foregroundColor(.white)

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "新密码（至少6位）",
                text: $forgotNewPassword
            )

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "确认新密码",
                text: $forgotConfirmPassword
            )

            if !forgotConfirmPassword.isEmpty && forgotNewPassword != forgotConfirmPassword {
                Text("两次密码不一致")
                    .font(.caption)
                    .foregroundColor(.red)
            }

            if let error = authManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Button(action: {
                Task {
                    await authManager.resetPassword(newPassword: forgotNewPassword)
                    if authManager.isAuthenticated {
                        showForgotPassword = false
                        showToastMessage("密码重置成功")
                    }
                }
            }) {
                Text("重置密码")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(10)
            }
            .disabled(!isValidForgotPassword())
            .opacity(isValidForgotPassword() ? 1 : 0.6)
        }
    }

    // MARK: - 辅助方法

    private func resetForms() {
        loginEmail = ""
        loginPassword = ""
        registerEmail = ""
        registerOTP = ""
        registerPassword = ""
        registerConfirmPassword = ""
        registerStep = .email
        authManager.clearError()
        authManager.resetOTPState()
    }

    private func resetForgotPasswordForm() {
        forgotEmail = ""
        forgotOTP = ""
        forgotNewPassword = ""
        forgotConfirmPassword = ""
        forgotStep = .email
        authManager.clearError()
        authManager.resetOTPState()
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    private func isValidPassword() -> Bool {
        return registerPassword.count >= 6 &&
               registerPassword == registerConfirmPassword
    }

    private func isValidForgotPassword() -> Bool {
        return forgotNewPassword.count >= 6 &&
               forgotNewPassword == forgotConfirmPassword
    }

    private func startResendCountdown() {
        resendCountdown = 60
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if resendCountdown > 0 {
                resendCountdown -= 1
            } else {
                timer.invalidate()
            }
        }
    }

    private func startForgotResendCountdown() {
        forgotResendCountdown = 60
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if forgotResendCountdown > 0 {
                forgotResendCountdown -= 1
            } else {
                timer.invalidate()
            }
        }
    }

    private func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showToast = false
            }
        }
    }
}

// MARK: - 支持类型和组件

enum AuthTab {
    case login
    case register
}

enum RegisterStep: Int {
    case email = 1
    case otp = 2
    case password = 3
}

enum ForgotPasswordStep {
    case email
    case otp
    case password
}

// Tab 按钮
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .gray)

                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(isSelected ? .orange : .clear)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// 自定义文本输入框
struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)

            TextField(placeholder, text: $text)
                .foregroundColor(.white)
                .keyboardType(keyboardType)
                .autocapitalization(.none)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }
}

// 自定义密码输入框
struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)

            SecureField(placeholder, text: $text)
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }
}

// 步骤指示器
struct StepIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? Color.orange : Color.gray.opacity(0.3))
                    .frame(width: 10, height: 10)

                if step < totalSteps {
                    Rectangle()
                        .fill(step < currentStep ? Color.orange : Color.gray.opacity(0.3))
                        .frame(height: 2)
                }
            }
        }
        .padding(.vertical, 10)
    }
}

// OTP 输入视图
struct OTPInputView: View {
    @Binding var otp: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<6, id: \.self) { index in
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 45, height: 55)

                    Text(otp.count > index ? String(otp[otp.index(otp.startIndex, offsetBy: index)]) : "")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
        }
        .background(
            TextField("", text: $otp)
                .keyboardType(.numberPad)
                .focused($isFocused)
                .opacity(0)
                .onChange(of: otp) { newValue in
                    if newValue.count > 6 {
                        otp = String(newValue.prefix(6))
                    }
                }
        )
        .onTapGesture {
            isFocused = true
        }
        .onAppear {
            isFocused = true
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthManager())
}

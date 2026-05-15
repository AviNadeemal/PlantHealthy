import SwiftUI

// MARK: - Splash View
struct SplashView: View {
    @State private var scale = 0.7
    @State private var opacity = 0.0

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#1a5c2e"), Color(hex: "#3aab62")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.white.opacity(0.15))
                        .frame(width: 90, height: 90)
                    Text("🌱").font(.system(size: 48))
                }
                .scaleEffect(scale)
                Text("AgriSmart")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("SMART FARMING FOR SRI LANKA")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .kerning(1.5)
            }
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    scale = 1.0; opacity = 1.0
                }
            }
        }
    }
}

// MARK: - Login View
struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var mobile = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var goSignUp = false
    @State private var goRecovery = false
    @State private var faceIDError: String? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(colors: [Color(hex: "#1a5c2e"), Color(hex: "#2d8a4e")],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                            .frame(height: 220)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 10) {
                                Text("🌱").font(.title2)
                                Text("AgriSmart").font(.title3).fontWeight(.bold).foregroundColor(.white)
                            }
                            Text("Welcome Back").font(.title).fontWeight(.bold).foregroundColor(.white)
                            Text("Sign in to your farm account").font(.subheadline).foregroundColor(.white.opacity(0.75))
                        }
                        .padding(.horizontal, 24).padding(.bottom, 24)
                    }

                    VStack(spacing: 16) {
                        // Fields
                        VStack(spacing: 0) {
                            FormField(label: "Mobile / Email", text: $mobile,
                                      placeholder: "+94 7X XXX XXXX", keyboardType: .phonePad)
                            Divider().padding(.leading, 14)
                            HStack {
                                FormField(label: "Password", text: $password,
                                          placeholder: "Enter your password", isSecure: !showPassword)
                                Button { showPassword.toggle() } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary).padding(.trailing, 14)
                                }
                            }
                        }
                        .background(Color.agriCard)
                        .cornerRadius(14)
                        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)

                        HStack {
                            Spacer()
                            Button("Forgot Password?") { goRecovery = true }
                                .font(.subheadline).foregroundColor(.agriGreen)
                        }

                        if let err = authVM.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill").foregroundColor(.red)
                                Text(err).font(.caption).foregroundColor(.red)
                            }
                            .padding(10).background(Color.red.opacity(0.08)).cornerRadius(10)
                        }

                        AgriButton(title: "Sign In", icon: "arrow.right.circle",
                                   isLoading: authVM.isLoading) {
                            Task {
                                await authVM.login(mobile: mobile, password: password)
                                if authVM.errorMessage == nil {
                                    KeychainService.shared.saveCredentials(mobile: mobile, password: password)
                                }
                            }
                        }

                        // Divider
                        HStack {
                            Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 1)
                            Text("or").font(.caption).foregroundColor(.secondary)
                            Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 1)
                        }

                        // Face ID
                        if BiometricAuthService.shared.isBiometricAvailable {
                            Button {
                                faceIDError = nil
                                Task {
                                    guard KeychainService.shared.hasCredentials else {
                                        faceIDError = "Sign in with your mobile & password first to enable \(BiometricAuthService.shared.biometricTypeName)."
                                        return
                                    }
                                    let ok = await BiometricAuthService.shared.authenticate(
                                        reason: "Sign in to AgriSmart")
                                    if ok {
                                        if let creds = KeychainService.shared.getCredentials() {
                                            await authVM.login(mobile: creds.mobile, password: creds.password)
                                        }
                                    } else {
                                        faceIDError = "\(BiometricAuthService.shared.biometricTypeName) was cancelled or failed. Try again."
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: BiometricAuthService.shared.biometricType == .faceID ? "faceid" : "touchid")
                                        .font(.title3)
                                    Text("Sign in with \(BiometricAuthService.shared.biometricTypeName)")
                                        .font(.subheadline).fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity).frame(height: 50)
                                .background(Color.agriCard)
                                .cornerRadius(14)
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.secondary.opacity(0.2)))
                            }
                            .foregroundColor(.primary)

                            if let faceIDErr = faceIDError {
                                HStack {
                                    Image(systemName: "faceid").foregroundColor(.orange)
                                    Text(faceIDErr).font(.caption).foregroundColor(.secondary)
                                }
                                .padding(10).background(Color.orange.opacity(0.08)).cornerRadius(10)
                            }
                        }

                        // Spacer so content isn't hidden behind the fixed bottom bar
                        Spacer().frame(height: 80)
                    }
                    .padding(20)
                }
            }

            // Fixed "Create Account" bar always visible at bottom
            VStack(spacing: 0) {
                Divider()
                Button(action: { goSignUp = true }) {
                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundColor(.secondary)
                            Text("Create Account")
                                .fontWeight(.semibold)
                                .foregroundColor(.agriGreen)
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundColor(.agriGreen)
                        }
                        .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                }
                .background(Color.agriBackground)
            }
        }
        .navigationBarHidden(true)
        .ignoresSafeArea(edges: .top)
        .background(Color.agriBackground)
        .navigationDestination(isPresented: $goSignUp) { SignUpView() }
        .navigationDestination(isPresented: $goRecovery) { PasswordRecoveryView() }
    }
}

// MARK: - Sign Up View
struct SignUpView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var fullName = ""
    @State private var mobile = ""
    @State private var district = ""
    @State private var farmName = ""
    @State private var farmSizeText = ""
    @State private var primaryCrop = "Paddy"
    @State private var password = ""
    @State private var confirmPassword = ""

    let districts = ["Colombo","Gampaha","Kalutara","Kandy","Matale","Nuwara Eliya",
                     "Galle","Matara","Hambantota","Jaffna","Kilinochchi","Mannar",
                     "Vavuniya","Mullativu","Trincomalee","Batticaloa","Ampara",
                     "Kurunegala","Puttalam","Anuradhapura","Polonnaruwa","Badulla",
                     "Monaragala","Ratnapura","Kegalle"]

    var passwordsMatch: Bool { password == confirmPassword && !password.isEmpty }
    var farmSize: Double { Double(farmSizeText) ?? 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(colors: [Color(hex: "#1a5c2e"), Color(hex: "#2d8a4e")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(height: 160)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Create Account").font(.title).fontWeight(.bold).foregroundColor(.white)
                        Text("Join thousands of smart farmers").font(.subheadline).foregroundColor(.white.opacity(0.75))
                    }
                    .padding(.horizontal, 24).padding(.bottom, 24)
                }

                VStack(spacing: 16) {
                    // Personal Info
                    GroupBox(label: Label("Personal Information", systemImage: "person.fill")) {
                        VStack(spacing: 0) {
                            FormField(label: "Full Name", text: $fullName, placeholder: "Enter your full name")
                            Divider().padding(.leading, 14)
                            FormField(label: "Mobile Number", text: $mobile,
                                      placeholder: "+94 7X XXX XXXX", keyboardType: .phonePad)
                        }
                    }

                    // Farm Info
                    GroupBox(label: Label("Farm Information", systemImage: "leaf.fill")) {
                        VStack(spacing: 0) {
                            FormField(label: "Farm Name", text: $farmName, placeholder: "e.g. Kumara's Farm")
                            Divider().padding(.leading, 14)
                            HStack {
                                FormField(label: "Farm Size (Acres)", text: $farmSizeText,
                                          placeholder: "e.g. 2.5", keyboardType: .decimalPad)
                            }
                            Divider().padding(.leading, 14)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("District")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary).textCase(.uppercase).kerning(0.4)
                                Picker("District", selection: $district) {
                                    Text("Select District").tag("")
                                    ForEach(districts, id: \.self) { Text($0).tag($0) }
                                }
                                .labelsHidden()
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            Divider().padding(.leading, 14)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Primary Crop")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary).textCase(.uppercase).kerning(0.4)
                                Picker("Primary Crop", selection: $primaryCrop) {
                                    ForEach(CropType.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) }
                                }
                                .labelsHidden()
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                        }
                    }

                    // Security
                    GroupBox(label: Label("Security", systemImage: "lock.fill")) {
                        VStack(spacing: 0) {
                            FormField(label: "Password", text: $password,
                                      placeholder: "Create a strong password", isSecure: true)
                            Divider().padding(.leading, 14)
                            FormField(label: "Confirm Password", text: $confirmPassword,
                                      placeholder: "Repeat your password", isSecure: true)
                            if !confirmPassword.isEmpty && !passwordsMatch {
                                HStack {
                                    Image(systemName: "exclamationmark.circle.fill").foregroundColor(.red)
                                    Text("Passwords do not match").font(.caption).foregroundColor(.red)
                                }
                                .padding(.horizontal, 14).padding(.bottom, 8)
                            }
                        }
                    }

                    if let err = authVM.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill").foregroundColor(.red)
                            Text(err).font(.caption).foregroundColor(.red)
                        }
                        .padding(10).background(Color.red.opacity(0.08)).cornerRadius(10)
                    }

                    AgriButton(title: "Create Account 🌱", isLoading: authVM.isLoading) {
                        guard passwordsMatch, !fullName.isEmpty, !mobile.isEmpty,
                              !farmName.isEmpty, !district.isEmpty, farmSize > 0 else { return }
                        Task {
                            await authVM.signUp(fullName: fullName, mobile: mobile,
                                                district: district, farmName: farmName,
                                                farmSize: farmSize, primaryCrop: primaryCrop,
                                                password: password)
                            if authVM.errorMessage == nil {
                                KeychainService.shared.saveCredentials(mobile: mobile, password: password)
                            }
                        }
                    }

                    Text("By creating an account you agree to our Terms of Service and Privacy Policy.")
                        .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.agriBackground)
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - Password Recovery View
struct PasswordRecoveryView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var mobile = ""
    @State private var step = 1
    @State private var otpCode = ""
    @State private var newPassword = ""
    @State private var otpSent = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.agriGreen.opacity(0.1)).frame(width: 80, height: 80)
                        Image(systemName: step == 1 ? "key.fill" : step == 2 ? "number.circle.fill" : "lock.rotation")
                            .font(.system(size: 34)).foregroundColor(.agriGreen)
                    }
                    Text(step == 1 ? "Reset Password" : step == 2 ? "Enter OTP" : "New Password")
                        .font(.title2).fontWeight(.bold)
                    Text(step == 1 ? "Enter your registered mobile number to receive an OTP"
                         : step == 2 ? "Enter the 6-digit code sent to your mobile"
                         : "Create a new secure password")
                        .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                // Step indicator
                HStack(spacing: 0) {
                    ForEach(1...3, id: \.self) { s in
                        ZStack {
                            Circle().fill(s <= step ? Color.agriGreen : Color.secondary.opacity(0.2))
                                .frame(width: 28, height: 28)
                            Text("\(s)").font(.caption.bold())
                                .foregroundColor(s <= step ? .white : .secondary)
                        }
                        if s < 3 {
                            Rectangle().fill(s < step ? Color.agriGreen : Color.secondary.opacity(0.2))
                                .frame(height: 2).frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal, 40)

                VStack(spacing: 14) {
                    if step == 1 {
                        VStack(spacing: 0) {
                            FormField(label: "Registered Mobile", text: $mobile,
                                      placeholder: "+94 7X XXX XXXX", keyboardType: .phonePad)
                        }
                        .background(Color.agriCard).cornerRadius(14)

                        AgriButton(title: "Send OTP Code", icon: "paperplane.fill",
                                   isLoading: authVM.isLoading) {
                            Task {
                                await authVM.resetPassword(mobile: mobile)
                                otpSent = true; step = 2
                            }
                        }
                    } else if step == 2 {
                        VStack(spacing: 0) {
                            FormField(label: "OTP Code", text: $otpCode,
                                      placeholder: "6-digit code", keyboardType: .numberPad)
                        }
                        .background(Color.agriCard).cornerRadius(14)

                        AgriButton(title: "Verify Code") { step = 3 }
                        Button("Resend Code") { Task { await authVM.resetPassword(mobile: mobile) } }
                            .font(.subheadline).foregroundColor(.agriGreen)
                    } else {
                        VStack(spacing: 0) {
                            FormField(label: "New Password", text: $newPassword,
                                      placeholder: "Create a strong password", isSecure: true)
                        }
                        .background(Color.agriCard).cornerRadius(14)

                        AgriButton(title: "Reset Password", icon: "checkmark.circle") {
                            dismiss()
                        }
                    }
                }

                if otpSent && step == 2 {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Text("OTP sent to \(mobile)").font(.caption).foregroundColor(.secondary)
                    }
                    .padding(10).background(Color.green.opacity(0.08)).cornerRadius(10)
                }
            }
            .padding(.horizontal, 24)
        }
        .navigationTitle("Recover Account")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.agriBackground)
    }
}

// MARK: - Color hex extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a,r,g,b) = (255,(int>>8)*17,(int>>4&0xF)*17,(int&0xF)*17)
        case 6: (a,r,g,b) = (255,int>>16,int>>8&0xFF,int&0xFF)
        case 8: (a,r,g,b) = (int>>24,int>>16&0xFF,int>>8&0xFF,int&0xFF)
        default: (a,r,g,b) = (255,0,0,0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

import SwiftUI

/// Logo: biały obrys MacBooka na czarnym tle.
struct AppMark: View {
    var size: CGFloat = 40
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.22)
            .fill(Color.black)
            .frame(width: size, height: size)
            .overlay(
                Image("Laptop")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
                    .padding(size * 0.16)
            )
            .accessibilityHidden(true)
    }
}

struct LanguagePicker: View {
    @AppStorage("lang", store: L.defaults) private var lang = "pl"
    var body: some View {
        Picker(L.t("language"), selection: $lang) {
            Text("Polski").tag("pl")
            Text("English").tag("en")
        }
        .pickerStyle(.segmented)
        .onChange(of: lang) { _, _ in Sound.shared.tab() }
    }
}

struct AuthView: View {
    @EnvironmentObject var store: AppStore
    @State private var signUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var message: String?
    @State private var bad = false
    @State private var busy = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LanguagePicker()
                VStack(alignment: .leading, spacing: 10) {
                    AppMark(size: 44)
                    Text(L.t("appName")).font(.system(size: 28, weight: .semibold)).lineLimit(1)
                    Text(L.t("tagline")).font(.system(size: 17)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if store.canUseAccounts {
                    Card(padding: 16) {
                        Picker("", selection: $signUp) {
                            Text(L.t("signIn")).tag(false)
                            Text(L.t("signUp")).tag(true)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        if signUp {
                            field(L.t("name")) { TextField("", text: $name).textContentType(.givenName) }
                        }
                        field(L.t("email")) {
                            TextField("", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        field(L.t("password")) {
                            SecureField("", text: $password).textContentType(signUp ? .newPassword : .password)
                        }
                        if signUp {
                            Text(L.t("passwordHint")).font(.system(size: 12)).foregroundStyle(Theme.muted)
                        }
                        if let message {
                            Text(message).font(.system(size: 13)).foregroundStyle(bad ? Theme.negative : Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Button(signUp ? L.t("signUp") : L.t("signIn")) { submit() }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(busy || email.isEmpty || password.count < 6 || (signUp && name.isEmpty))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Button(L.t("continueWithout")) {
                        Sound.shared.click()
                        store.useLocal()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    Text(L.t("withoutHint")).font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
                LegalLinks()
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
    }

    private func field<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 14, weight: .medium))
            content()
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
        }
    }

    private func submit() {
        busy = true
        message = nil
        Sound.shared.click()
        Task {
            do {
                if signUp {
                    try await store.signUp(email: email.trimmingCharacters(in: .whitespaces), password: password, name: name)
                } else {
                    try await store.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
                }
            } catch APIError.confirmEmail {
                bad = false
                message = L.t("checkEmail")
                signUp = false
            } catch {
                bad = true
                message = L.t("error", ["msg": error.localizedDescription])
            }
            busy = false
        }
    }
}

struct LegalLinks: View {
    var body: some View {
        HStack(spacing: 16) {
            NavigationLink(L.t("privacy")) { LegalView(doc: .privacy) }
            NavigationLink(L.t("terms")) { LegalView(doc: .terms) }
            NavigationLink(L.t("info")) { LegalView(doc: .info) }
        }
        .font(.system(size: 12))
        .foregroundStyle(Theme.muted)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

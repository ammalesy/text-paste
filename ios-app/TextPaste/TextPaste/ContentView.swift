import SwiftUI
import Security

// ─────────────────────────────────────────────
// MARK: - Config
// ─────────────────────────────────────────────

enum Config {
    /// Base URL of your TextPaste server
    static let baseURL = "https://text-paste-nu.vercel.app"
}

// ─────────────────────────────────────────────
// MARK: - Keychain helper
// ─────────────────────────────────────────────

enum Keychain {
    private static let service = "com.textpaste.app"
    private static let account = "auth_token"

    static func save(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        SecItemDelete(query as CFDictionary)
        let attrs = query.merging([kSecValueData: data]) { $1 }
        SecItemAdd(attrs as CFDictionary, nil)
    }

    static func load() -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      account,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8)
        else { return nil }
        return token
    }

    static func delete() {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// ─────────────────────────────────────────────
// MARK: - AuthManager
// ─────────────────────────────────────────────

@MainActor
class AuthManager: ObservableObject {
    @Published var token: String? = nil
    @Published var isCheckingToken = true

    init() {
        // Restore token from Keychain, then verify it's still valid
        if let saved = Keychain.load() {
            Task { await verifyAndSet(saved) }
        } else {
            isCheckingToken = false
        }
    }

    // POST /api/login  → returns token or throws
    func login(password: String) async throws {
        guard let url = URL(string: "\(Config.baseURL)/api/login") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["password": password])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw AuthError.serverError("ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้")
        }
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]

        if http.statusCode == 200, let t = json["token"] as? String {
            Keychain.save(t)
            token = t
        } else {
            let msg = json["error"] as? String ?? "รหัสผ่านไม่ถูกต้อง"
            throw AuthError.unauthorized(msg)
        }
    }

    func logout() {
        Keychain.delete()
        token = nil
    }

    // Silently verify saved token; discard if expired
    private func verifyAndSet(_ saved: String) async {
        defer { isCheckingToken = false }
        guard let url = URL(string: "\(Config.baseURL)/api/login?token=\(saved.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let valid = json["valid"] as? Bool, valid
        else {
            Keychain.delete()
            return
        }
        token = saved
    }
}

enum AuthError: LocalizedError {
    case unauthorized(String)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized(let msg): return msg
        case .serverError(let msg):  return msg
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Models
// ─────────────────────────────────────────────

struct RecordEntry: Identifiable {
    let id = UUID()
    let filename: String
    let content: String

    /// e.g. "2026-02-23T14-05-30-record.txt" → "14:05:30"
    var timeString: String {
        let parts = filename.split(separator: "T")
        guard parts.count >= 2 else { return "" }
        let timePart = String(parts[1].prefix(8)).replacingOccurrences(of: "-", with: ":")
        return timePart
    }
}

struct Pagination {
    let page: Int
    let totalPages: Int
    let total: Int
}

// ─────────────────────────────────────────────
// MARK: - Records ViewModel
// ─────────────────────────────────────────────

@MainActor
class RecordsViewModel: ObservableObject {
    @Published var groupedRecords: [(date: String, entries: [RecordEntry])] = []
    @Published var pagination: Pagination = Pagination(page: 1, totalPages: 1, total: 0)
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var copiedFilename: String? = nil

    /// Called by the parent view when token becomes available / changes
    var token: String = ""

    private var currentPage = 1

    func loadRecords(page: Int = 1) {
        currentPage = page
        isLoading = true
        errorMessage = nil

        guard let url = URL(string: "\(Config.baseURL)/api/records?page=\(page)") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(token, forHTTPHeaderField: "x-auth-token")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false

                if let error = error {
                    self.errorMessage = "ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้: \(error.localizedDescription)"
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else {
                    self.errorMessage = "ไม่สามารถอ่านข้อมูลได้"
                    return
                }

                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                    self.errorMessage = "Token ไม่ถูกต้องหรือหมดอายุ"
                    return
                }

                guard let grouped = json["grouped"] as? [String: [[String: Any]]],
                      let paginationData = json["pagination"] as? [String: Any]
                else {
                    self.errorMessage = "รูปแบบข้อมูลไม่ถูกต้อง"
                    return
                }

                let sortedDates = grouped.keys.sorted(by: >)
                self.groupedRecords = sortedDates.compactMap { date in
                    let entries = grouped[date]?.compactMap { dict -> RecordEntry? in
                        guard let filename = dict["filename"] as? String,
                              let content = dict["content"] as? String
                        else { return nil }
                        return RecordEntry(filename: filename, content: content)
                    } ?? []
                    return entries.isEmpty ? nil : (date: date, entries: entries)
                }

                self.pagination = Pagination(
                    page: paginationData["page"] as? Int ?? 1,
                    totalPages: paginationData["totalPages"] as? Int ?? 1,
                    total: paginationData["total"] as? Int ?? 0
                )
            }
        }.resume()
    }

    func copyAndDelete(entry: RecordEntry) {
        // 1. Copy to clipboard
        UIPasteboard.general.string = entry.content
        copiedFilename = entry.filename

        // 2. Delete from server
        guard let url = URL(string: "\(Config.baseURL)/api/delete?filename=\(entry.filename.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(token, forHTTPHeaderField: "x-auth-token")

        URLSession.shared.dataTask(with: request) { [weak self] _, _, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                // Remove entry from local state
                self.groupedRecords = self.groupedRecords.compactMap { group in
                    let remaining = group.entries.filter { $0.filename != entry.filename }
                    return remaining.isEmpty ? nil : (date: group.date, entries: remaining)
                }
                // Clear copied highlight after 2s
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    if self.copiedFilename == entry.filename {
                        self.copiedFilename = nil
                    }
                }
            }
        }.resume()
    }

    func loadPrevPage() {
        guard pagination.page > 1 else { return }
        loadRecords(page: pagination.page - 1)
    }

    func loadNextPage() {
        guard pagination.page < pagination.totalPages else { return }
        loadRecords(page: pagination.page + 1)
    }

    /// async version for SwiftUI .refreshable — keeps the spinner visible until done
    func refreshRecords() async {
        await withCheckedContinuation { continuation in
            loadRecords(page: 1)
            // Wait until isLoading flips back to false
            Task {
                while self.isLoading {
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                }
                continuation.resume()
            }
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Root View
// ─────────────────────────────────────────────

struct ContentView: View {
    @StateObject private var auth = AuthManager()

    var body: some View {
        Group {
            if auth.isCheckingToken {
                // Splash while verifying saved token
                VStack(spacing: 16) {
                    ProgressView()
                    Text("กำลังตรวจสอบ…")
                        .foregroundStyle(.secondary)
                }
            } else if auth.token == nil {
                LoginView(auth: auth)
                    .transition(.opacity)
            } else {
                RecordsRootView(auth: auth)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: auth.token == nil)
    }
}

// ─────────────────────────────────────────────
// MARK: - Login View
// ─────────────────────────────────────────────

struct LoginView: View {
    @ObservedObject var auth: AuthManager
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo / title
            VStack(spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                Text("TextPaste")
                    .font(.largeTitle.bold())
                Text("กรอกรหัสผ่านเพื่อเข้าใช้งาน")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer().frame(height: 48)

            // Password field
            VStack(spacing: 12) {
                SecureField("รหัสผ่าน", text: $password)
                    .textContentType(.password)
                    .submitLabel(.go)
                    .focused($focused)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onSubmit { Task { await doLogin() } }

                if let err = errorMessage {
                    Label(err, systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }

                Button {
                    Task { await doLogin() }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("เข้าสู่ระบบ")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || password.isEmpty)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .onAppear { focused = true }
    }

    private func doLogin() async {
        guard !password.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            try await auth.login(password: password)
        } catch {
            errorMessage = error.localizedDescription
            password = ""
            focused = true
        }
        isLoading = false
    }
}

// ─────────────────────────────────────────────
// MARK: - Records Root (after login)
// ─────────────────────────────────────────────

struct RecordsRootView: View {
    @ObservedObject var auth: AuthManager
    @StateObject private var vm = RecordsViewModel()

    var body: some View {
        NavigationStack {
            RecordsListView(vm: vm)
                .navigationTitle("TextPaste")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            vm.loadRecords(page: 1)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("ออกจากระบบ", role: .destructive) {
                            auth.logout()
                        }
                        .font(.callout)
                    }
                }
        }
        .onAppear {
            vm.token = auth.token ?? ""
            vm.loadRecords(page: 1)
        }
        // Re-sync token if it ever changes
        .onChange(of: auth.token) { _, newToken in
            vm.token = newToken ?? ""
        }
    }
}

struct RecordsListView: View {
    @ObservedObject var vm: RecordsViewModel

    var body: some View {
        List {
            if vm.isLoading {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("กำลังโหลด…")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 60)
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else if let error = vm.errorMessage {
                HStack {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button("ลองใหม่") {
                            vm.loadRecords(page: 1)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 60)
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else if vm.groupedRecords.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("ยังไม่มีบันทึก")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 60)
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(vm.groupedRecords, id: \.date) { group in
                    Section(header: Text(formatDate(group.date)).fontWeight(.semibold)) {
                        ForEach(group.entries) { entry in
                            RecordRowView(
                                entry: entry,
                                isCopied: vm.copiedFilename == entry.filename,
                                onCopy: { vm.copyAndDelete(entry: entry) }
                            )
                        }
                    }
                }

                // Pagination
                if vm.pagination.totalPages > 1 {
                    Section {
                        PaginationView(
                            pagination: vm.pagination,
                            onPrev: { vm.loadPrevPage() },
                            onNext: { vm.loadNextPage() }
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await vm.refreshRecords()
        }
    }

    private func formatDate(_ dateStr: String) -> String {
        // dateStr = "2026-02-23"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "th_TH")
        guard let date = formatter.date(from: dateStr) else { return dateStr }

        let display = DateFormatter()
        display.dateStyle = .full
        display.locale = Locale(identifier: "th_TH")
        return display.string(from: date)
    }
}

struct RecordRowView: View {
    let entry: RecordEntry
    let isCopied: Bool
    let onCopy: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.timeString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Text(entry.content)
                    .font(.body)
                    .lineLimit(3)
                    .foregroundStyle(.primary)
            }

            Spacer()

            Button(action: onCopy) {
                Label(
                    isCopied ? "คัดลอกแล้ว" : "คัดลอก",
                    systemImage: isCopied ? "checkmark" : "doc.on.doc"
                )
                .font(.caption)
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isCopied ? Color.green.opacity(0.15) : Color.accentColor.opacity(0.1))
                .foregroundStyle(isCopied ? .green : .accentColor)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isCopied)
        }
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.2), value: isCopied)
    }
}

struct PaginationView: View {
    let pagination: Pagination
    let onPrev: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack {
            Button(action: onPrev) {
                Label("ก่อนหน้า", systemImage: "chevron.left")
            }
            .disabled(pagination.page <= 1)

            Spacer()

            Text("หน้า \(pagination.page) / \(pagination.totalPages)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: onNext) {
                Label("ถัดไป", systemImage: "chevron.right")
                    .labelStyle(.titleAndIcon)
            }
            .disabled(pagination.page >= pagination.totalPages)
        }
        .padding(.vertical, 4)
    }
}

// ─────────────────────────────────────────────
// MARK: - Preview
// ─────────────────────────────────────────────

#Preview {
    ContentView()
}

// APIClient.swift
import Foundation

// ─────────────────────────────────────────────
// MARK: - API Client
// ─────────────────────────────────────────────

enum APIError: LocalizedError {
    case unauthorized(String)
    case serverError(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized(let m): return m
        case .serverError(let m):  return m
        case .networkError(let m): return m
        }
    }
}

final class APIClient {
    static let shared = APIClient()
    private init() {}

    // POST /api/login → token
    func login(password: String) async throws -> String {
        guard let url = URL(string: "\(Config.baseURL)/api/login") else {
            throw APIError.networkError("URL ไม่ถูกต้อง")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["password": password])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError("ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้")
        }
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]

        if http.statusCode == 200, let t = json["token"] as? String {
            return t
        }
        let msg = json["error"] as? String ?? "รหัสผ่านไม่ถูกต้อง"
        throw APIError.unauthorized(msg)
    }

    // GET /api/login?token=... → valid bool
    func verifyToken(_ token: String) async -> Bool {
        let encoded = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "\(Config.baseURL)/api/login?token=\(encoded)") else { return false }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let valid = json["valid"] as? Bool
        else { return false }
        return valid
    }

    // POST /api/save → saves text, returns filename
    func save(text: String, token: String) async throws {
        guard let url = URL(string: "\(Config.baseURL)/api/save") else {
            throw APIError.networkError("URL ไม่ถูกต้อง")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(token, forHTTPHeaderField: "x-auth-token")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["text": text])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError("ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้")
        }
        if http.statusCode == 200 { return }
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        let msg = json["error"] as? String ?? "บันทึกไม่สำเร็จ (status \(http.statusCode))"
        if http.statusCode == 401 { throw APIError.unauthorized(msg) }
        throw APIError.serverError(msg)
    }
}

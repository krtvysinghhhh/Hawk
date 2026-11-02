import Foundation
import HawkCore

/// High-performance asynchronous HTTP client powered by native URLSession.
public actor HawkHttpClient {
    public static let shared = HawkHttpClient()

    private let session: URLSession
    private let defaultUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    public init(configuration: URLSessionConfiguration = .default) {
        configuration.timeoutIntervalForRequest = 15.0
        configuration.timeoutIntervalForResource = 60.0
        configuration.waitsForConnectivity = true
        self.session = URLSession(configuration: configuration)
    }

    /// Executes an HTTP request with automatic exponential retry on transient failures.
    public func request(
        url: URL,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil,
        maxRetries: Int = 2
    ) async throws -> (Data, HTTPURLResponse) {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.httpBody = body
        req.setValue(defaultUserAgent, forHTTPHeaderField: "User-Agent")

        for (k, v) in headers {
            req.setValue(v, forHTTPHeaderField: k)
        }

        var attempt = 0
        var currentDelay: Double = 0.5

        while true {
            attempt += 1
            do {
                let (data, response) = try await session.data(for: req)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw HawkError.networkError("Invalid non-HTTP response")
                }

                if httpResponse.statusCode == 429 || (500...599).contains(httpResponse.statusCode) {
                    if attempt <= maxRetries {
                        try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                        currentDelay *= 2.0
                        continue
                    }
                }

                return (data, httpResponse)
            } catch {
                if attempt <= maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                    currentDelay *= 2.0
                    continue
                }
                throw HawkError.networkError(error.localizedDescription)
            }
        }
    }

    /// Convenience JSON GET request.
    public func getJSON<T: Decodable>(
        url: URL,
        headers: [String: String] = [:],
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        let (data, response) = try await request(url: url, method: "GET", headers: headers)
        guard (200...299).contains(response.statusCode) else {
            throw HawkError.invalidResponse(response.statusCode)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw HawkError.decodeError(error.localizedDescription)
        }
    }

    /// Convenience JSON POST request.
    public func postJSON<T: Decodable, B: Encodable>(
        url: URL,
        body: B,
        headers: [String: String] = [:],
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        let bodyData = try encoder.encode(body)
        var fullHeaders = headers
        fullHeaders["Content-Type"] = "application/json"

        let (data, response) = try await request(url: url, method: "POST", headers: fullHeaders, body: bodyData)
        guard (200...299).contains(response.statusCode) else {
            throw HawkError.invalidResponse(response.statusCode)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw HawkError.decodeError(error.localizedDescription)
        }
    }
}

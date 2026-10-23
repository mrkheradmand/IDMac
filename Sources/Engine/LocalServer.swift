import Foundation
import Network
import AppKit

@MainActor
public final class LocalServer: ObservableObject {
    public static let shared = LocalServer()

    @Published public var isRunning: Bool = false
    @Published public var port: UInt16 = 23485

    private var listener: NWListener?

    private init() {}

    public func start() {
        guard listener == nil else { return }

        do {
            let tcpOptions = NWProtocolTCP.Options()
            let params = NWParameters(tls: nil, tcp: tcpOptions)
            params.requiredLocalEndpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host("127.0.0.1"),
                port: NWEndpoint.Port(rawValue: port)!
            )

            let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
            self.listener = listener

            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        print("LocalServer listening on http://127.0.0.1:\(self?.port ?? 23485)")
                    case .failed(let error):
                        print("LocalServer failed: \(error.localizedDescription)")
                        self?.isRunning = false
                    case .cancelled:
                        self?.isRunning = false
                    default:
                        break
                    }
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                connection.start(queue: .main)
                Task { @MainActor [weak self] in
                    self?.handleConnection(connection)
                }
            }

            listener.start(queue: .main)
        } catch {
            print("Failed to start LocalServer on port \(port): \(error.localizedDescription)")
        }
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let data = content, let requestString = String(data: data, encoding: .utf8) {
                    let response = self.processRequest(requestString)
                    self.sendResponse(response, on: connection)
                } else {
                    connection.cancel()
                }
            }
        }
    }

    private func processRequest(_ request: String) -> (status: String, body: String) {
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            return ("400 Bad Request", "{\"error\":\"Empty request\"}")
        }

        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            return ("400 Bad Request", "{\"error\":\"Malformed request line\"}")
        }

        let method = parts[0].uppercased()
        let path = parts[1]

        // CORS Preflight
        if method == "OPTIONS" {
            return ("200 OK", "")
        }

        // Health check endpoint
        if (method == "GET" && (path == "/health" || path == "/ping" || path == "/")) {
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.6"
            return ("200 OK", "{\"status\":\"ok\",\"app\":\"IDMac\",\"version\":\"\(version)\"}")
        }

        // Add download endpoint
        if method == "POST" && (path == "/add" || path == "/download") {
            // Find body separated by double CRLF
            if let bodyRange = request.range(of: "\r\n\r\n") {
                let bodyString = String(request[bodyRange.upperBound...])
                if let bodyData = bodyString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
                   let urlString = json["url"] as? String, !urlString.isEmpty {

                    Task { @MainActor in
                        self.handleIncomingDownload(urlString: urlString, filename: json["filename"] as? String)
                    }

                    return ("200 OK", "{\"success\":true,\"message\":\"Download added to IDMac\"}")
                }
            }
            return ("400 Bad Request", "{\"error\":\"Missing or invalid 'url' in JSON body\"}")
        }

        return ("404 Not Found", "{\"error\":\"Unknown endpoint\"}")
    }

    private func handleIncomingDownload(urlString: String, filename: String?) {
        guard let context = DownloadCoordinator.shared.modelContext else {
            print("Cannot add download from browser: ModelContext is nil")
            return
        }

        let downloadsFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!

        Task {
            await DownloadCoordinator.shared.addDownload(
                urlString: urlString,
                destinationFolder: downloadsFolder,
                connectionCount: UserDefaults.standard.integer(forKey: "defaultConnections") > 0 ? UserDefaults.standard.integer(forKey: "defaultConnections") : 8,
                modelContext: context,
                startImmediately: true
            )

            // Bring IDMac to front if configured
            MenuBarManager.shared.showMainWindow()
        }
    }

    private func sendResponse(_ response: (status: String, body: String), on connection: NWConnection) {
        let bodyData = response.body.data(using: .utf8) ?? Data()
        let headers = [
            "HTTP/1.1 \(response.status)",
            "Content-Type: application/json; charset=utf-8",
            "Access-Control-Allow-Origin: *",
            "Access-Control-Allow-Methods: GET, POST, OPTIONS",
            "Access-Control-Allow-Headers: Content-Type, Authorization",
            "Content-Length: \(bodyData.count)",
            "Connection: close"
        ].joined(separator: "\r\n") + "\r\n\r\n"

        var responseData = headers.data(using: .utf8) ?? Data()
        responseData.append(bodyData)

        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

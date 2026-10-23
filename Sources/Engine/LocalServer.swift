import Foundation
import AppKit
import Darwin

@MainActor
public final class LocalServer: ObservableObject {
    public static let shared = LocalServer()

    @Published public var isRunning: Bool = false
    @Published public var port: UInt16 = 23485
    @Published public var lastErrorMessage: String? = nil

    private var serverSocket: Int32 = -1
    private let serverQueue = DispatchQueue(label: "com.idmac.localserver.accept", qos: .userInitiated)

    private init() {}

    public func start() {
        stop()

        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else {
            let err = String(cString: strerror(errno))
            self.lastErrorMessage = "Failed to create socket: \(err)"
            print("[LocalServer] \(self.lastErrorMessage!)")
            self.isRunning = false
            return
        }

        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindResult == 0 else {
            let err = String(cString: strerror(errno))
            close(fd)
            self.lastErrorMessage = "Failed to bind to 127.0.0.1:\(port): \(err)"
            print("[LocalServer] \(self.lastErrorMessage!)")
            self.isRunning = false
            return
        }

        guard listen(fd, 32) == 0 else {
            let err = String(cString: strerror(errno))
            close(fd)
            self.lastErrorMessage = "Failed to listen on 127.0.0.1:\(port): \(err)"
            print("[LocalServer] \(self.lastErrorMessage!)")
            self.isRunning = false
            return
        }

        self.serverSocket = fd
        self.isRunning = true
        self.lastErrorMessage = nil
        print("[LocalServer] Listening successfully on http://127.0.0.1:\(port)")

        let currentSocket = fd
        serverQueue.async { [weak self] in
            self?.acceptLoop(serverFd: currentSocket)
        }
    }

    public func stop() {
        isRunning = false
        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }
    }

    nonisolated private func acceptLoop(serverFd: Int32) {
        while true {
            var clientAddr = sockaddr_in()
            var clientLen = socklen_t(MemoryLayout<sockaddr_in>.size)

            let clientFd = withUnsafeMutablePointer(to: &clientAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    accept(serverFd, $0, &clientLen)
                }
            }

            guard clientFd >= 0 else {
                // If socket was closed by stop(), exit accept loop cleanly
                break
            }

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.handleClient(clientFd)
            }
        }
    }

    nonisolated private func handleClient(_ fd: Int32) {
        defer { close(fd) }

        var buffer = [UInt8](repeating: 0, count: 65536)
        let bytesRead = read(fd, &buffer, buffer.count)
        guard bytesRead > 0 else { return }

        guard let requestString = String(bytes: buffer[0..<bytesRead], encoding: .utf8) else {
            sendResponse(status: "400 Bad Request", body: "{\"error\":\"Malformed encoding\"}", to: fd)
            return
        }

        let lines = requestString.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            sendResponse(status: "400 Bad Request", body: "{\"error\":\"Empty request\"}", to: fd)
            return
        }

        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            sendResponse(status: "400 Bad Request", body: "{\"error\":\"Malformed request line\"}", to: fd)
            return
        }

        let method = parts[0].uppercased()
        let path = parts[1]

        // 1. CORS Preflight
        if method == "OPTIONS" {
            sendResponse(status: "200 OK", body: "", to: fd)
            return
        }

        // 2. Health & Heartbeat
        if method == "GET" && (path == "/health" || path == "/ping" || path == "/") {
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.9"
            let body = "{\"status\":\"ok\",\"app\":\"IDMac\",\"version\":\"\(version)\"}"
            sendResponse(status: "200 OK", body: body, to: fd)
            return
        }

        // 3. Add Download Endpoint
        if method == "POST" && (path == "/add" || path == "/download") {
            if let bodyRange = requestString.range(of: "\r\n\r\n") {
                let bodyString = String(requestString[bodyRange.upperBound...])
                if let bodyData = bodyString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
                   let urlString = json["url"] as? String, !urlString.isEmpty {

                    let filename = json["filename"] as? String
                    Task { @MainActor in
                        self.handleIncomingDownload(urlString: urlString, filename: filename)
                    }

                    sendResponse(status: "200 OK", body: "{\"success\":true,\"message\":\"Download added to IDMac\"}", to: fd)
                    return
                }
            }
            sendResponse(status: "400 Bad Request", body: "{\"error\":\"Missing or invalid 'url' in JSON body\"}", to: fd)
            return
        }

        sendResponse(status: "404 Not Found", body: "{\"error\":\"Unknown endpoint\"}", to: fd)
    }

    private func handleIncomingDownload(urlString: String, filename: String?) {
        guard let context = DownloadCoordinator.shared.modelContext else {
            print("[LocalServer] Cannot add download from browser: ModelContext is nil")
            return
        }

        let downloadsFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!

        Task {
            MenuBarManager.shared.showMainWindow()

            await DownloadCoordinator.shared.addDownload(
                urlString: urlString,
                customFilename: filename,
                destinationFolder: downloadsFolder,
                connectionCount: UserDefaults.standard.integer(forKey: "defaultConnections") > 0 ? UserDefaults.standard.integer(forKey: "defaultConnections") : 8,
                modelContext: context,
                startImmediately: true
            )
        }
    }

    nonisolated private func sendResponse(status: String, body: String, to fd: Int32) {
        let bodyBytes = body.utf8
        let headers = [
            "HTTP/1.1 \(status)",
            "Content-Type: application/json; charset=utf-8",
            "Access-Control-Allow-Origin: *",
            "Access-Control-Allow-Methods: GET, POST, OPTIONS",
            "Access-Control-Allow-Headers: Content-Type, Authorization",
            "Content-Length: \(bodyBytes.count)",
            "Connection: close"
        ].joined(separator: "\r\n") + "\r\n\r\n"

        let fullResponse = headers + body
        _ = fullResponse.withCString { ptr in
            write(fd, ptr, strlen(ptr))
        }
    }
}

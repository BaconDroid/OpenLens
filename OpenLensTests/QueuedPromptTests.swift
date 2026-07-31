import Foundation
import Testing
@testable import OpenLens

struct QueuedPromptTests {
    @Test func queuedPromptUsesTheSchedulerQueueContract() async throws {
        let transport = QueuedPromptTransport()
        let client = OpenCodeClient(
            baseURL: try #require(URL(string: "https://opencode.example.com")),
            transport: transport
        )

        try await client.queuePrompt(sessionID: "session-1", text: "Run the tests after this finishes.")

        let request = try #require(transport.recordedRequest())
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/api/session/session-1/prompt")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let body = try #require(request.httpBody)
        let payload = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        let prompt = try #require(payload["prompt"] as? [String: String])
        #expect(prompt["text"] == "Run the tests after this finishes.")
        #expect(payload["delivery"] as? String == "queue")
    }

    @MainActor
    @Test func queuesFollowUpInDemoWithoutStoppingTheActiveTurn() {
        let client = ChatClient(demoMode: true)
        client.currentSession = OCSession(
            id: "session-1",
            title: "Test",
            time: OCSessionTime(created: 0, updated: 0)
        )
        client.isLoading = true
        client.responseState = .generating
        client.inputText = "Check the test results next."

        client.queuePrompt()

        #expect(client.inputText.isEmpty)
        #expect(client.messages.last?.role == .user)
        #expect(client.messages.last?.content == "Check the test results next.")
        #expect(client.isLoading)
        #expect(client.responseState == .generating)
    }
}

nonisolated private final class QueuedPromptTransport: OpenCodeTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var request: URLRequest?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lock.lock()
        self.request = request
        lock.unlock()

        let fallbackURL = URL(string: "https://opencode.example.com")!
        let response = HTTPURLResponse(
            url: request.url ?? fallbackURL,
            statusCode: 202,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data("{}".utf8), response)
    }

    func makeEventStream(
        request: URLRequest,
        deliveryQueue: DispatchQueue,
        callbacks: OpenCodeEventStreamCallbacks
    ) -> any OpenCodeEventStream {
        UnusedQueuedPromptEventStream()
    }

    func recordedRequest() -> URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        return request
    }
}

nonisolated private final class UnusedQueuedPromptEventStream: OpenCodeEventStream, @unchecked Sendable {
    func start() {}
    func suspend() {}
    func resume() {}
    func cancel() {}
}

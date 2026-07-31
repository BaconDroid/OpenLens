import Foundation
import Testing
@testable import OpenLens

struct OpenCodeClientRevertTests {
    @Test func revertAcceptsTheUpdatedSessionResponse() async throws {
        let transport = RevertMessageTransport(
            responseBody: Data(
                #"{"id":"session-1","title":"Test","time":{"created":0,"updated":1},"revert":{"messageID":"message-2"}}"#.utf8
            )
        )
        let client = OpenCodeClient(
            baseURL: try #require(URL(string: "https://opencode.example.com")),
            transport: transport
        )

        let session = try #require(
            try await client.revertMessage(sessionID: "session-1", messageID: "message-2")
        )

        #expect(session.id == "session-1")
        #expect(session.revert?.messageID == "message-2")

        let request = try #require(transport.recordedRequest())
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/session/session-1/revert")

        let body = try #require(request.httpBody)
        let payload = try #require(try JSONSerialization.jsonObject(with: body) as? [String: String])
        #expect(payload == ["messageID": "message-2"])
    }

    @Test func revertAcceptsLegacyBooleanAcknowledgement() async throws {
        let transport = RevertMessageTransport(responseBody: Data("true".utf8))
        let client = OpenCodeClient(
            baseURL: try #require(URL(string: "https://opencode.example.com")),
            transport: transport
        )

        let session = try await client.revertMessage(
            sessionID: "session-1",
            messageID: "message-2"
        )

        #expect(session == nil)
    }
}

nonisolated private final class RevertMessageTransport: OpenCodeTransport, @unchecked Sendable {
    private let lock = NSLock()
    private let responseBody: Data
    private var request: URLRequest?

    init(responseBody: Data) {
        self.responseBody = responseBody
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lock.lock()
        self.request = request
        lock.unlock()

        let fallbackURL = URL(string: "https://opencode.example.com")!
        let response = HTTPURLResponse(
            url: request.url ?? fallbackURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (responseBody, response)
    }

    func makeEventStream(
        request: URLRequest,
        deliveryQueue: DispatchQueue,
        callbacks: OpenCodeEventStreamCallbacks
    ) -> any OpenCodeEventStream {
        UnusedRevertMessageEventStream()
    }

    func recordedRequest() -> URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        return request
    }
}

nonisolated private final class UnusedRevertMessageEventStream: OpenCodeEventStream, @unchecked Sendable {
    func start() {}
    func suspend() {}
    func resume() {}
    func cancel() {}
}

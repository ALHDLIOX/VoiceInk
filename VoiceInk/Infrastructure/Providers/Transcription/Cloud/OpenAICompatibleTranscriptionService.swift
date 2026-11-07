import Foundation

class OpenAICompatibleTranscriptionService {
    func transcribe(
        audioURL: URL, model: CustomCloudModel, context: TranscriptionRequestContext, timeout: TimeInterval
    ) async throws -> String {
        guard let url = URL(string: model.apiEndpoint) else {
            throw NSError(
                domain: "CustomWhisperTranscriptionService", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid API endpoint URL"])
        }

        // Audio-capable chat models (e.g. seed-2-0-lite) have no /audio/transcriptions route;
        // an endpoint ending in /chat/completions sends the recording as input_audio instead.
        if url.path.hasSuffix("/chat/completions") {
            return try await transcribeViaChat(
                url: url, audioURL: audioURL, model: model, context: context, timeout: timeout)
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(model.apiKey)", forHTTPHeaderField: "Authorization")

        let body = try buildRequestBody(
            audioURL: audioURL, modelName: model.modelName, boundary: boundary, context: context)
        // Ephemeral session per request: the shared session persists Alt-Svc and upgrades
        // new connections to HTTP/3, but QUIC bulk uploads blackhole behind VPNs that drop
        // full-size UDP datagrams (e.g. GlobalProtect), timing out large audio uploads.
        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.upload(for: request, from: body)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudTranscriptionError.networkError(URLError(.badServerResponse))
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = String(data: data, encoding: .utf8) ?? "No error message"
            throw CloudTranscriptionError.apiRequestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        do {
            return try JSONDecoder().decode(TranscriptionResponse.self, from: data).text
        } catch {
            throw CloudTranscriptionError.noTranscriptionReturned
        }
    }

    private func buildRequestBody(
        audioURL: URL, modelName: String, boundary: String, context: TranscriptionRequestContext
    ) throws -> Data {
        guard let audioData = try? Data(contentsOf: audioURL) else {
            throw CloudTranscriptionError.audioFileNotFound
        }

        let selectedLanguage = context.language ?? "auto"
        let crlf = "\r\n"
        var body = Data()

        func append(_ string: String) { body.append(string.data(using: .utf8)!) }
        func field(_ name: String, _ value: String) {
            append("--\(boundary)\(crlf)")
            append("Content-Disposition: form-data; name=\"\(name)\"\(crlf)\(crlf)")
            body.append(value.data(using: .utf8)!)
            append(crlf)
        }

        append("--\(boundary)\(crlf)")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(audioURL.lastPathComponent)\"\(crlf)")
        append("Content-Type: audio/wav\(crlf)\(crlf)")
        body.append(audioData)
        append(crlf)

        field("model", modelName)
        field("response_format", "json")
        field("temperature", "0")

        if selectedLanguage != "auto" && !selectedLanguage.isEmpty {
            field("language", selectedLanguage)
        }

        // Send the dictionary as the OpenAI `prompt` hint so the server can bias spelling toward it.
        if let terms = context.vocabulary?.terms, !terms.isEmpty {
            field("prompt", terms.prefix(200).joined(separator: ", "))
        }

        append("--\(boundary)--\(crlf)")
        return body
    }

    private func transcribeViaChat(
        url: URL, audioURL: URL, model: CustomCloudModel, context: TranscriptionRequestContext,
        timeout: TimeInterval
    ) async throws -> String {
        guard let audioData = try? Data(contentsOf: audioURL) else {
            throw CloudTranscriptionError.audioFileNotFound
        }

        var instruction = "把这段语音逐字转写成文字，加上中文标点。英文专有名词优先按下面词表的原样拼写和大小写输出"
            + "（发音相近的就是词表里的词）。只输出转写结果，不要解释。"
        if let language = context.language, language != "auto", !language.isEmpty {
            instruction += "\n语言：\(language)"
        }
        if let terms = context.vocabulary?.terms, !terms.isEmpty {
            instruction += "\n词表：" + terms.joined(separator: "、")
        }

        let payload: [String: Any] = [
            "model": model.modelName,
            "temperature": 0,
            "thinking": ["type": "disabled"],
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "input_audio", "input_audio": ["data": audioData.base64EncodedString(), "format": "wav"]],
                    ["type": "text", "text": instruction],
                ],
            ]],
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(model.apiKey)", forHTTPHeaderField: "Authorization")
        let body = try JSONSerialization.data(withJSONObject: payload)

        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.upload(for: request, from: body)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudTranscriptionError.networkError(URLError(.badServerResponse))
        }
        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = String(data: data, encoding: .utf8) ?? "No error message"
            throw CloudTranscriptionError.apiRequestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        guard let decoded = try? JSONDecoder().decode(ChatResponse.self, from: data),
            let text = decoded.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty
        else {
            throw CloudTranscriptionError.noTranscriptionReturned
        }
        return text
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String? }
            let message: Message
        }
        let choices: [Choice]
    }

    private struct TranscriptionResponse: Decodable {
        let text: String
        let language: String?
        let duration: Double?
    }
}

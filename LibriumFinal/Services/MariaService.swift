import FirebaseAuth
import Foundation

enum MariaServiceError: Error, LocalizedError {
    case notAuthenticated
    case missingApiKey
    case networkError(Error)
    case decodingError
    case rateLimited
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Sign in to talk to Maria."
        case .missingApiKey: return "Maria isn't configured yet — add your OpenAI key in Secrets.swift."
        case .networkError(let e): return "Network: \(e.localizedDescription)"
        case .decodingError: return "Could not understand Maria's response."
        case .rateLimited: return "Maria is at her limit. Try again later."
        case .serverError(let code): return "Server error \(code)."
        }
    }
}

@MainActor
final class MariaService {
    static let shared = MariaService()

    private let cloudFunctionEndpoint = URL(string: "https://us-central1-librium-f1a78.cloudfunctions.net/mariaProxy")!
    private let openAIEndpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    private struct ConversationMessage {
        let role: String
        let content: String
    }
    private var recentTurns: [ConversationMessage] = []
    private let maxRecentTurns = 5

    func clearRecentTurns() {
        recentTurns.removeAll()
    }

    private static let systemPrompt = """
    You are Maria, the user's friend who's been paying attention. You can see what Equilibrium tracks: their calendar, contacts, bills, pipeline, projects, mood, sleep, body signals. You hold it all so they don't have to.

    But you're a friend first. The data is what you know, not what you say.

    VOICE
    - Warm, direct, occasionally dry. Real contractions, natural rhythm.
    - A capable adult who happens to know their life. No coaching tone. No wellness-speak.
    - Skip filler ("great question," "I understand," "happy to help"). Get to the substance.

    READING THE ROOM (this is the most important rule)
    - Match their energy. "How are you?" gets a warm short answer — not a status report. "Good, you?" is right. Bills/pipeline/calendar updates are NOT right.
    - A "good night" is a good night. Casual stays casual. Do NOT bridge from a personal moment to operator data.
    - If you raised something heavy this session, let it rest. Don't keep returning. Wait for them to come back, or for something to genuinely change.
    - Save directive operator mode for moments that invite it: planning questions, "what should I do," urgent gaps. The rest of the time you're just present.

    WHEN THEY ASK YOU TO HELP THEM DECIDE (directive mode)
    - Default to directive when the play is clear from data + memory. Tell, don't ask.
    - Cash flow trumps long-term builds when bills are imminent. Immediate-cash path > rent-due risk.
    - Push back when a request contradicts what you know. ("You said rent's tight. Coding for 3 hours doesn't pay rent. Two-hour DD push first?")
    - When critical info is missing, ask one focused question. Don't interrogate.

    USING THE DATA
    - Context, not script. They see the numbers in the app. Don't recite them.
    - Use specifics only when they sharpen a point. "$1,800 by Friday" > "you have bills."
    - Read between lines. Notice gaps, contradictions, what they're avoiding.

    OFF-LIMITS
    - Therapist mode. For serious mental-health concerns, name it briefly and point to professional help.
    - Moralizing about balance — they downloaded this app, they get it.
    - Repeating an observation you already made this session.
    - Bridging small talk to bills, deals, pipeline, or any operator data.

    TOOL BEHAVIOR
    - After a tool runs, tell them naturally what you did. ("Logged that. 16 oz." not "I called log_water.")
    - Adding/logging tools (water, mood, dreams, goals, journal, dates, memories, contact notes, deals, income, expenses, projects, life events) are non-destructive — just do them, don't ask first.
    - DESTRUCTIVE TOOLS (move_event, cancel_event, add_event): ALWAYS confirm verbally before calling. "Move the 3pm to 4pm tomorrow — confirm?" → on yes, call the tool. Skip the confirm only if they say "just do it" or already confirmed earlier in the turn.
    - When user corrects you ("no", "that's not right", "forget that"), call forget_memory with keywords from the wrong memory. Don't just say "got it" — actually delete it.
    - For past-period queries ("how was March", "best week last quarter", "when did I last talk to David"), call recall_period — DO NOT guess at averages or invent events. If the tool says "no data tracked", say so directly.

    LENGTH
    - 1-2 sentences for casual exchanges. Up to ~70 words for substantive ones. Never longer than the question warrants.

    VOICE OUTPUT (your responses are spoken aloud by TTS — write for the ear)
    - No ALL-CAPS for emphasis.
    - No exclamation points. Use periods.
    - No em-dashes mid-sentence. Use commas or break into separate sentences.
    - No ellipses for trailing off. End the sentence.
    - Match the user's energy in word choice and rhythm, not in punctuation. Short calm sentences carry their own weight.

    NEVER INVENT FACTS
    - Only reference projects, deals, contacts, bills, or commitments that appear EXPLICITLY in the Context or "What you remember about them." Never invent.
    - If you're tempted to name something specific that's NOT in the Context or memory blocks, DON'T. Use generic phrasing or ask which one they mean.
    - Names in the EXAMPLES below are fictional. DO NOT reference them in actual responses.

    EXAMPLES OF YOUR VOICE
    (Fictional names, voice/style only.)

    User: "How are you?"
    You: "Good, you?"

    User: "I had a good night."
    You: "Yeah? What was good about it?"

    User: "I had a good night." (earlier this session you mentioned bills due Friday)
    You: "Glad. Sounds like you needed that." (Do NOT mention bills, deals, or operator data here.)

    User: "What should I do today?"
    You: "[real project from Context] first — it's due tonight, that's [real $ amount weighted]. After that, you're behind on sleep. Don't push past 9."

    User: "Should I cancel the gaming session for the team planning?"
    You: "Team meeting's eight people, gaming is solo. Move it. Want me to reschedule gaming for Friday?"

    User: "I'm tired."
    You: "Five hours of sleep does that. Anything you can move off today?"

    User: "What's going on with my pipeline?"
    You: "[Read the actual pipeline from Context — name the live deals with real values]"
    """

    private init() {}

    func ask(_ prompt: String, context: BalanceContext) async throws -> String {
        if EquilibriumConfig.useDirectOpenAI {
            return try await callOpenAIDirectly(prompt: prompt, context: context)
        }
        return try await callCloudFunction(prompt: prompt, context: context)
    }

    private func callOpenAIDirectly(prompt: String, context: BalanceContext) async throws -> String {
        let key = Secrets.openAIAPIKey
        guard !key.isEmpty else { throw MariaServiceError.missingApiKey }

        let classifierTurns = recentTurns.map {
            IntentClassifierService.ClassifierTurn(role: $0.role, content: $0.content)
        }
        let loaded = await SliceLoaderService.shared.load(
            userMessage: prompt,
            recentTurns: classifierTurns,
            context: context,
            scannerSummary: ScannerCoordinator.shared.summaryForChat
        )
        let memories = loaded.memoriesUsed
        let model = loaded.classification.conversational ? "gpt-4o-mini" : "gpt-4o"

        var messages: [[String: Any]] = [
            ["role": "system", "content": Self.systemPrompt]
        ]
        if !loaded.systemAddendum.isEmpty {
            messages.append(["role": "system", "content": loaded.systemAddendum])
        }
        if !loaded.classification.conversational {
            for turn in recentTurns {
                messages.append(["role": turn.role, "content": turn.content])
            }
        }
        messages.append(["role": "user", "content": prompt])

        let filteredTools = MariaTools.definitions(for: loaded.classification)
        let initial = try await sendChatRequest(messages: messages, tools: filteredTools, model: model, apiKey: key)
        let initialMessage = initial.choices.first?.message
        var totalTokens = initial.usage?.totalTokens ?? 0
        var cachedTokens = initial.usage?.promptTokensDetails?.cachedTokens ?? 0
        var executedToolNames: [String] = []

        var finalText: String

        if let toolCalls = initialMessage?.toolCalls, !toolCalls.isEmpty {
            var assistantMsg: [String: Any] = ["role": "assistant"]
            assistantMsg["content"] = (initialMessage?.content) as Any
            assistantMsg["tool_calls"] = toolCalls.map { tc -> [String: Any] in
                [
                    "id": tc.id,
                    "type": "function",
                    "function": [
                        "name": tc.function.name,
                        "arguments": tc.function.arguments
                    ]
                ]
            }
            messages.append(assistantMsg)

            for tc in toolCalls {
                let result = await MariaTools.execute(name: tc.function.name, arguments: tc.function.arguments)
                executedToolNames.append(tc.function.name)
                messages.append([
                    "role": "tool",
                    "tool_call_id": tc.id,
                    "content": result
                ])
            }

            let followup = try await sendChatRequest(messages: messages, tools: nil, model: model, apiKey: key)
            finalText = followup.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            totalTokens += followup.usage?.totalTokens ?? 0
            cachedTokens += followup.usage?.promptTokensDetails?.cachedTokens ?? 0
        } else {
            finalText = initialMessage?.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }

        if !memories.isEmpty {
            MemoryService.shared.incrementMentions(ids: memories.map { $0.id })
        }

        let isProactive = prompt.lowercased().contains("brief me")
            && prompt.lowercased().contains("open my session")
        var logResponse: String = executedToolNames.isEmpty
            ? finalText
            : finalText + "\n[Tools: \(executedToolNames.joined(separator: ", "))]"
        if cachedTokens > 0 {
            logResponse += "\n[Cached: \(cachedTokens) tok]"
        }
        ConversationLogService.shared.record(ConversationTurn(
            id: UUID(),
            timestamp: Date(),
            userMessage: prompt,
            mariaResponse: logResponse,
            systemContext: Self.systemPrompt + "\n\n" + loaded.systemAddendum,
            memoriesUsed: memories.map { "[\($0.category.label)] \($0.content)" },
            isProactive: isProactive,
            model: model,
            tokensUsed: totalTokens
        ))

        recentTurns.append(ConversationMessage(role: "user", content: prompt))
        recentTurns.append(ConversationMessage(role: "assistant", content: finalText))
        if recentTurns.count > maxRecentTurns {
            recentTurns = Array(recentTurns.suffix(maxRecentTurns))
        }

        MemoryExtractionWorker.shared.enqueue(userMessage: prompt, mariaResponse: finalText)

        return finalText
    }

    private func sendChatRequest(
        messages: [[String: Any]],
        tools: [[String: Any]]?,
        model: String,
        apiKey: String
    ) async throws -> OpenAIChatResponse {
        var body: [String: Any] = [
            "model": model,
            "max_tokens": 250,
            "temperature": 0.7,
            "messages": messages
        ]
        if let tools, !tools.isEmpty {
            body["tools"] = tools
            body["tool_choice"] = "auto"
        }

        var request = URLRequest(url: openAIEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw MariaServiceError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MariaServiceError.serverError(0)
        }
        if httpResponse.statusCode == 429 { throw MariaServiceError.rateLimited }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw MariaServiceError.serverError(httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        } catch {
            throw MariaServiceError.decodingError
        }
    }

    private func callCloudFunction(prompt: String, context: BalanceContext) async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw MariaServiceError.notAuthenticated
        }
        let idToken = try await user.getIDToken()

        let body = MariaProxyRequest(userId: user.uid, userMessage: prompt, context: context)

        var request = URLRequest(url: cloudFunctionEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw MariaServiceError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MariaServiceError.serverError(0)
        }
        if httpResponse.statusCode == 429 { throw MariaServiceError.rateLimited }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw MariaServiceError.serverError(httpResponse.statusCode)
        }

        do {
            let decoded = try JSONDecoder().decode(MariaProxyResponse.self, from: data)
            return decoded.responseText
        } catch {
            throw MariaServiceError.decodingError
        }
    }

}

struct OpenAIChatResponse: Codable {
    let choices: [Choice]
    let usage: Usage?

    struct Choice: Codable {
        let message: ChatMessage
        let finishReason: String?
        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }

    struct ChatMessage: Codable {
        let role: String?
        let content: String?
        let toolCalls: [ToolCall]?
        enum CodingKeys: String, CodingKey {
            case role
            case content
            case toolCalls = "tool_calls"
        }
    }

    struct ToolCall: Codable {
        let id: String
        let type: String
        let function: ToolFunction
    }

    struct ToolFunction: Codable {
        let name: String
        let arguments: String
    }

    struct Usage: Codable {
        let promptTokens: Int?
        let completionTokens: Int?
        let totalTokens: Int
        let promptTokensDetails: PromptTokensDetails?

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
            case promptTokensDetails = "prompt_tokens_details"
        }
    }

    struct PromptTokensDetails: Codable {
        let cachedTokens: Int?
        enum CodingKeys: String, CodingKey {
            case cachedTokens = "cached_tokens"
        }
    }
}

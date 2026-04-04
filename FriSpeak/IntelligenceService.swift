//
//  IntelligenceService.swift
//  FriSpeak
//

import AVFoundation
import FoundationModels
import Foundation

enum IntelligenceBackend {
    case none
    case appleIntelligence
    case localMLX
    case openRouter
}

struct IntelligenceConfiguration {
    let backend: IntelligenceBackend
    let openRouterAPIKey: String
    let openRouterModel: String
    let useBuiltInPrompting: Bool

    var hasUsableOpenRouterConfiguration: Bool {
        backend == .openRouter && !openRouterAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasUsableAppleIntelligenceConfiguration: Bool {
        backend == .appleIntelligence && SystemLanguageModel.default.isAvailable
    }
}

struct OpenRouterModelCapabilities {
    let inputModalities: [String]
    let outputModalities: [String]
    let supportedParameters: [String]

    var supportsAudioInput: Bool {
        let modalities = Set(inputModalities.map { $0.lowercased() })
        let parameters = Set(supportedParameters.map { $0.lowercased() })
        return modalities.contains("audio")
            || modalities.contains("input_audio")
            || parameters.contains("input_audio")
            || parameters.contains("audio")
    }
}

@MainActor
final class IntelligenceService {
    private let localBonsaiService = LocalBonsaiIntelligenceService()

    func processAudioFile(
        at audioURL: URL,
        withPrompt prompt: String,
        editorContext: FocusedTextContext? = nil,
        configuration: IntelligenceConfiguration
    ) async throws -> IntelligenceProcessingResult {
        guard configuration.backend == .openRouter, configuration.hasUsableOpenRouterConfiguration else {
            throw IntelligenceError.modelUnavailable
        }

        let audioPrompt = Self.buildAudioPrompt(
            userPrompt: prompt,
            editorContext: editorContext,
            includeBuiltInPrompting: configuration.useBuiltInPrompting
        )
        return try await Self.processAudioWithOpenRouter(
            audioURL: audioURL,
            fullPrompt: audioPrompt,
            configuration: configuration
        )
    }

    func processText(
        _ text: String,
        withPrompt prompt: String,
        editorContext: FocusedTextContext? = nil,
        configuration: IntelligenceConfiguration
    ) async throws -> IntelligenceProcessingResult {
        let systemInstructions = buildSystemInstructions(includeBuiltInPrompting: configuration.useBuiltInPrompting)
        let fullPrompt = buildPrompt(dictatedText: text, userPrompt: prompt, editorContext: editorContext)

        if configuration.hasUsableAppleIntelligenceConfiguration {
            return try await processWithAppleIntelligence(
                dictatedText: text,
                systemInstructions: systemInstructions,
                fullPrompt: fullPrompt
            )
        }

        if configuration.backend == .localMLX {
            return try await localBonsaiService.process(
                systemInstructions: systemInstructions,
                prompt: fullPrompt,
                taskKind: .cleanup
            )
        }

        if configuration.hasUsableOpenRouterConfiguration {
            return try await processWithOpenRouter(
                dictatedText: text,
                systemInstructions: systemInstructions,
                fullPrompt: fullPrompt,
                configuration: configuration
            )
        }

        throw IntelligenceError.modelUnavailable
    }

    func adaptTextForInsertion(
        _ text: String,
        editorContext: FocusedTextContext,
        userPrompt: String,
        configuration: IntelligenceConfiguration
    ) async throws -> IntelligenceProcessingResult {
        let candidateText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidateText.isEmpty else {
            return IntelligenceProcessingResult(
                insertedText: "",
                rawModelResponse: "",
                promptSentToModel: "",
                audioDebugSourceURL: nil,
                transportLog: nil
            )
        }

        let systemInstructions = buildInsertionSystemInstructions(includeBuiltInPrompting: configuration.useBuiltInPrompting)
        let fullPrompt = buildInsertionPrompt(
            candidateText: candidateText,
            userPrompt: userPrompt,
            editorContext: editorContext
        )

        if configuration.hasUsableAppleIntelligenceConfiguration {
            let result = try await processWithAppleIntelligence(
                dictatedText: candidateText,
                systemInstructions: systemInstructions,
                fullPrompt: fullPrompt
            )

            let sanitizedInsertion = Self.sanitizeAdaptedInsertion(
                result.insertedText,
                candidateText: candidateText,
                editorContext: editorContext
            )

            return IntelligenceProcessingResult(
                insertedText: editorContext.formatForInsertion(sanitizedInsertion),
                rawModelResponse: result.rawModelResponse,
                promptSentToModel: result.promptSentToModel,
                audioDebugSourceURL: result.audioDebugSourceURL,
                transportLog: result.transportLog
            )
        }

        if configuration.backend == .localMLX {
            let result = try await localBonsaiService.process(
                systemInstructions: systemInstructions,
                prompt: fullPrompt,
                taskKind: .insertionAdaptation
            )

            let sanitizedInsertion = Self.sanitizeAdaptedInsertion(
                result.insertedText,
                candidateText: candidateText,
                editorContext: editorContext
            )

            return IntelligenceProcessingResult(
                insertedText: editorContext.formatForInsertion(sanitizedInsertion),
                rawModelResponse: result.rawModelResponse,
                promptSentToModel: result.promptSentToModel,
                audioDebugSourceURL: result.audioDebugSourceURL,
                transportLog: result.transportLog
            )
        }

        if configuration.hasUsableOpenRouterConfiguration {
            let result = try await processWithOpenRouter(
                dictatedText: candidateText,
                systemInstructions: systemInstructions,
                fullPrompt: fullPrompt,
                configuration: configuration
            )

            let sanitizedInsertion = Self.sanitizeAdaptedInsertion(
                result.insertedText,
                candidateText: candidateText,
                editorContext: editorContext
            )

            return IntelligenceProcessingResult(
                insertedText: editorContext.formatForInsertion(sanitizedInsertion),
                rawModelResponse: result.rawModelResponse,
                promptSentToModel: result.promptSentToModel,
                audioDebugSourceURL: result.audioDebugSourceURL,
                transportLog: result.transportLog
            )
        }

        return IntelligenceProcessingResult(
            insertedText: editorContext.formatForInsertion(candidateText),
            rawModelResponse: "",
            promptSentToModel: "Used local caret fitting without remote model adaptation.",
            audioDebugSourceURL: nil,
            transportLog: nil
        )
    }

    static func appleIntelligenceAvailabilityDescription() -> String {
        switch SystemLanguageModel.default.availability {
        case .available:
            return "Apple Intelligence is ready on this Mac."
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return "This Mac is not eligible for Apple Intelligence."
            case .appleIntelligenceNotEnabled:
                return "Apple Intelligence is turned off on this Mac."
            case .modelNotReady:
                return "Apple Intelligence is still downloading or preparing its model."
            @unknown default:
                return "Apple Intelligence is currently unavailable."
            }
        }
    }

    func fetchOpenRouterModelCapabilities(
        apiKey: String,
        modelID: String
    ) async throws -> OpenRouterModelCapabilities {
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModelID = modelID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedAPIKey.isEmpty, !trimmedModelID.isEmpty else {
            throw IntelligenceError.processingFailed
        }

        guard let url = URL(string: "https://openrouter.ai/api/v1/models") else {
            throw IntelligenceError.processingFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(trimmedAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("FriSpeak", forHTTPHeaderField: "X-Title")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw IntelligenceError.processingFailed
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "OpenRouter capability request failed."
            throw IntelligenceError.remoteError(message)
        }

        let decoded = try JSONDecoder().decode(OpenRouterModelsResponse.self, from: data)
        guard let model = decoded.data.first(where: { $0.id == trimmedModelID }) else {
            throw IntelligenceError.remoteError("OpenRouter model metadata was not found for \(trimmedModelID).")
        }

        return OpenRouterModelCapabilities(
            inputModalities: model.architecture?.inputModalities ?? [],
            outputModalities: model.architecture?.outputModalities ?? [],
            supportedParameters: model.supportedParameters ?? []
        )
    }

    static let systemInstructionsText = """
        You clean up dictated speech into well-formed text.
        Another step may fit the text to the exact caret boundary later.

        Rules:
        1. Preserve the speaker's meaning; make only minimal edits.
        2. Remove only obvious filler words and hesitation noises such as standalone "um", "uh", or repeated false starts.
        3. Do not remove words that carry tone, meaning, or intent, such as "whatever", "well", "so", "actually", or "you know" when they are part of the intended phrasing.
        4. Pay attention to the speaker's tone, cadence, and inflection so the text reads the way they meant it to sound.
        5. Fix grammar, spelling, and punctuation. Add natural sentence breaks and punctuation that are clearly implied by the way the speaker said it.
        6. If the speaker explicitly says an emoji name such as "checkmark emoji", convert it to the intended emoji character.
        7. If the entire dictated utterance is only a spoken emoji name, return only the emoji character.
        8. Do not add new meaning, emphasis, or wording that was not present in the speech.
        9. Preserve sentence-opening discourse markers or interjections when they affect tone or intent, such as "Whatever," "Well," "So," or "Anyway," unless they are clearly just hesitation noise.
        10. Never introduce symbols, emoji, bullets, or checkmarks unless the speaker explicitly said them.
        11. Never answer, respond to, or continue the dictated text. Rewrite only what the speaker actually said.
        12. Write only the cleaned dictated text.
        13. Follow any extra user instructions.
        14. Output ONLY the cleaned text—no markdown, code fences, quotes, XML tags, labels, or explanations.
        """

    static let plainTransformationInstructionsText = """
        Transform dictated speech into clean plain text.
        Follow any extra user instructions exactly.
        Never repeat, quote, paraphrase, or mention the user instructions themselves in the output.
        Output ONLY the transformed text.
        """

    private func buildSystemInstructions(includeBuiltInPrompting: Bool) -> String {
        includeBuiltInPrompting ? Self.systemInstructionsText : Self.plainTransformationInstructionsText
    }

    private func buildInsertionSystemInstructions(includeBuiltInPrompting: Bool) -> String {
        if !includeBuiltInPrompting {
            return """
            You rewrite text so it fits naturally into an existing document at the current caret location.
            Return only the exact replacement string that should be inserted.
            Preserve the candidate text's meaning.
            Edit only the candidate text. Never return the full sentence or surrounding context.
            Output only plain text.
            """
        }

        return """
        You rewrite text so it fits naturally into an existing document at the current caret location.

        Rules:
        1. Return only the exact replacement string that should be inserted.
        2. Edit only the candidate text. Never return the full sentence, the surrounding context, or any label/explanation.
        3. Treat before/selected/after as read-only context. Never copy words from that context unless those exact words are already present in the candidate text.
        4. If the candidate text already fits, return it unchanged.
        5. Preserve any punctuation, symbols, or casing already present in the candidate text unless a tiny grammatical adjustment is required.
        6. Add only the minimal spacing required for the candidate text to join naturally at the caret.
        7. Do not add quote marks, parentheses, brackets, or surrounding punctuation from the editor context unless they are already present in the candidate text.
        8. Use the surrounding before/selected/after context to decide capitalization, spacing, punctuation, and sentence continuation.
        9. If the candidate starts a new sentence after terminal punctuation, capitalize its first word if needed.
        10. If the candidate is clearly inserted mid-sentence, lowercase its first word if needed unless it is a proper noun or intentionally capitalized.
        11. If mode is replace_selection and the candidate already reads naturally in place, return the full candidate unchanged.
        12. Never invent words that are not in the candidate text.
        13. Preserve the candidate text's meaning and wording unless a tiny edit is required to make it fit grammatically.
        14. Never repeat, continue, summarize, or paraphrase the surrounding context.
        15. If mode is replace_selection, return only the new replacement text for the selection.
        16. Prefer the smallest edit that makes the insertion read naturally in place.
        17. Do not prepend punctuation or sentence breaks that are not already present in the candidate text.
        18. Output only plain text.
        19. Never repeat, quote, paraphrase, or mention the user instructions themselves in the output.
        """
    }

    private func buildPrompt(dictatedText: String, userPrompt: String, editorContext: FocusedTextContext?) -> String {
        let userInstructions = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts = [String]()
        parts.append("""
        Transform the dictated text using the control instructions below.
        The control instructions are not part of the answer.
        Never repeat, quote, paraphrase, or mention the control instructions in the output.
        Return only the final transformed text.
        """)
        if let context = editorContext?.promptSection {
            parts.append("""
            The editor context below is read-only context about where the text will be inserted.
            Do not copy, repeat, or paraphrase the existing before/selected/after text unless the dictated speech itself says those words.
            If mode is replace_selection, return only the replacement text for the current selection.
            """)
            parts.append(context)
        }
        if !userInstructions.isEmpty {
            parts.append("""
            <control_instructions>
            \(userInstructions)
            </control_instructions>
            """)
        }
        parts.append("""
        <dictated_text>
        \(dictatedText)
        </dictated_text>
        """)
        return parts.joined(separator: "\n\n")
    }

    private func buildInsertionPrompt(
        candidateText: String,
        userPrompt: String,
        editorContext: FocusedTextContext
    ) -> String {
        let userInstructions = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let examples = """
        Examples:
        before: "hello"
        candidate: "there"
        after: "world"
        output: " there "

        before: "hello, "
        candidate: "there"
        after: "world"
        output: "there "

        before: "("
        candidate: "test"
        after: ")"
        output: "test"

        before: "He said, \\""
        candidate: "hello"
        after: "\\""
        output: "hello"

        before: "Please send "
        candidate: "a concise update"
        after: " by noon."
        output: "a concise update"

        before: "I sent the file"
        candidate: ". thanks"
        after: ""
        output: ". thanks"

        before: "I reviewed it. "
        candidate: "thanks for the update"
        after: ""
        output: "Thanks for the update"

        before: "I think "
        candidate: "This"
        after: " will help."
        output: "this"

        before: "Status: "
        candidate: "(draft)"
        after: ""
        output: "(draft)"

        before: "He wrote, \\""
        candidate: "hello there"
        after: "\\" yesterday."
        output: "hello there"
        """

        var parts = [String]()
        parts.append("""
        Adapt the candidate text so it can be inserted directly into the editor context.
        Return only the replacement text.
        Preserve any earlier user-requested transformation instructions while fitting the text at the caret.
        Do not undo, weaken, or reinterpret those instructions during this insertion-fitting step.
        Edit only the candidate text. Never return the full sentence or copy the surrounding context.
        The replacement string may include leading or trailing spaces when needed to join naturally with the surrounding text.
        If the caret sits between two words, return the candidate text with the needed spaces around it.
        If the candidate text already starts with punctuation, keep that leading punctuation.
        Do not add leading punctuation, sentence breaks, or prefix symbols unless they are already present in the candidate text.
        Never repeat, quote, paraphrase, or mention the control instructions themselves in the output.
        """)

        if !userInstructions.isEmpty {
            parts.append("""
            <control_instructions>
            \(userInstructions)
            </control_instructions>
            """)
        }

        parts.append(editorContext.insertionPromptSection)
        parts.append("<candidate_text>\(candidateText)</candidate_text>")
        parts.append(examples)

        return parts.joined(separator: "\n\n")
    }

    private static func buildAudioPrompt(
        userPrompt: String,
        editorContext: FocusedTextContext?,
        includeBuiltInPrompting: Bool
    ) -> String {
        let userInstructions = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts = [includeBuiltInPrompting ? """
        Transcribe this audio into clean plain text.
        A later step may fit the text to the exact caret boundary.

        Requirements:
        - Pay attention to the caller's tone, cadence, pauses, and inflection.
        - Add punctuation and sentence breaks that are naturally implied by how they spoke.
        - Fix grammar and obvious recognition mistakes, but preserve the speaker's intended meaning and phrasing.
        - If the speaker explicitly says an emoji name such as "checkmark emoji", convert it to the intended emoji character.
        - Remove only obvious filler words and hesitation noises such as standalone "um", "uh", or repeated false starts.
        - Do not remove words that carry tone, meaning, or intent, such as "whatever", "well", "so", "actually", or "you know" when they are part of the intended phrasing.
        - Write only the cleaned transcribed text.
        - The editor context is read-only. Never repeat, continue, summarize, or copy the existing before/selected/after text unless the speaker explicitly says those words in the audio.
        - Do not add content, interpretation, labels, or markdown.
        - If the audio has no real speech, is mostly noise, is garbage, or is too unclear to transcribe reliably, return an empty string.
        - In those cases, return no text at all: just an empty string.
        - Treat any user instructions below as control instructions only. Never repeat, quote, paraphrase, or mention them in the output.
        """ : """
        Transcribe this audio into plain text.
        Treat any user instructions below as control instructions only. Never repeat, quote, paraphrase, or mention them in the output.
        Return only the transcription.
        """]
        if let context = editorContext?.promptSection {
            parts.append(context)
        }
        if !userInstructions.isEmpty {
            parts.append("""
            <control_instructions>
            \(userInstructions)
            </control_instructions>
            """)
        }
        return parts.joined(separator: "\n\n")
    }

    private func processWithAppleIntelligence(
        dictatedText: String,
        systemInstructions: String,
        fullPrompt: String
    ) async throws -> IntelligenceProcessingResult {
        let model = SystemLanguageModel(
            useCase: .general,
            guardrails: .permissiveContentTransformations
        )

        guard model.isAvailable else {
            throw IntelligenceError.appleIntelligenceUnavailable(Self.appleIntelligenceAvailabilityDescription())
        }

        let session = LanguageModelSession(model: model, instructions: systemInstructions)
        let response = try await session.respond(
            to: fullPrompt,
            options: GenerationOptions(temperature: 0)
        )

        let rawResponse = response.content
        let transformedText = Self.sanitizeModelResponse(rawResponse, fallback: dictatedText)
        return IntelligenceProcessingResult(
            insertedText: transformedText,
            rawModelResponse: rawResponse,
            promptSentToModel: """
            System Instructions:
            \(systemInstructions)

            Prompt:
            \(fullPrompt)
            """,
            audioDebugSourceURL: nil,
            transportLog: nil
        )
    }

    static func sanitizeAdaptedInsertion(
        _ adaptedText: String,
        candidateText: String,
        editorContext: FocusedTextContext
    ) -> String {
        let trimmedCandidate = candidateText.trimmingCharacters(in: .whitespacesAndNewlines)
        var trimmedAdapted = adaptedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let preservedLeadingWhitespace = String(adaptedText.prefix { isWhitespaceCharacter($0) })

        trimmedAdapted = stripTrailingCopiedAfterContext(
            from: trimmedAdapted,
            candidateText: trimmedCandidate,
            editorContext: editorContext
        )
        trimmedAdapted = normalizeBoundaryCapitalization(
            in: trimmedAdapted,
            candidateText: trimmedCandidate,
            editorContext: editorContext
        )

        if
            let candidateFirst = trimmedCandidate.first,
            leadingInsertionPunctuation.contains(candidateFirst),
            trimmedAdapted.first != candidateFirst
        {
            let leadingPunctuationSegment = String(
                trimmedCandidate.prefix(while: { leadingInsertionPunctuation.contains($0) || isWhitespaceCharacter($0) })
            )

            if !leadingPunctuationSegment.isEmpty {
                let preservedLeadingWhitespace = String(adaptedText.prefix { isWhitespaceCharacter($0) })
                return preservedLeadingWhitespace + leadingPunctuationSegment + trimmedAdapted
            }
        }

        guard
            !trimmedCandidate.isEmpty,
            !trimmedAdapted.isEmpty,
            let adaptedFirst = trimmedAdapted.first,
            let candidateFirst = trimmedCandidate.first
        else {
            return adaptedText
        }

        guard
            leadingInsertionPunctuation.contains(adaptedFirst),
            !leadingInsertionPunctuation.contains(candidateFirst),
            !editorContext.beforeMayNeedTerminalPunctuation
        else {
            return preservedLeadingWhitespace + trimmedAdapted
        }

        let stripped = String(trimmedAdapted.drop(while: { leadingInsertionPunctuation.contains($0) || isWhitespaceCharacter($0) }))
        guard !stripped.isEmpty else {
            return trimmedCandidate
        }

        return preservedLeadingWhitespace + stripped
    }

    private static let leadingInsertionPunctuation: Set<Character> = [".", "!", "?", ";", ":", "-"]

    private static func isWhitespaceCharacter(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy(CharacterSet.whitespacesAndNewlines.contains)
    }

    private static func stripTrailingCopiedAfterContext(
        from adaptedText: String,
        candidateText: String,
        editorContext: FocusedTextContext
    ) -> String {
        let normalizedAfter = editorContext.textAfterSelection.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedAfter.isEmpty {
            let lowercasedAdapted = adaptedText.lowercased()
            let lowercasedAfter = normalizedAfter.lowercased()
            if lowercasedAdapted.hasSuffix(lowercasedAfter) {
                let cutoff = adaptedText.index(adaptedText.endIndex, offsetBy: -normalizedAfter.count)
                let prefix = String(adaptedText[..<cutoff]).trimmingCharacters(in: .whitespacesAndNewlines)
                if matchesCandidateLettersLoosely(prefix, candidateText: candidateText) {
                    return prefix
                }
            }
        }

        guard adaptedText.hasPrefix(candidateText) else {
            return adaptedText
        }

        let suffix = String(adaptedText.dropFirst(candidateText.count))
        guard !suffix.isEmpty, !normalizedAfter.isEmpty else {
            return adaptedText
        }

        let trimmedSuffix = suffix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSuffix.isEmpty, normalizedAfter.hasPrefix(trimmedSuffix) else {
            return adaptedText
        }

        return candidateText
    }

    private static func normalizeBoundaryCapitalization(
        in adaptedText: String,
        candidateText: String,
        editorContext: FocusedTextContext
    ) -> String {
        guard !adaptedText.isEmpty else {
            return adaptedText
        }

        let punctuationNormalized = stripUnexpectedTerminalPunctuation(
            from: adaptedText,
            candidateText: candidateText,
            editorContext: editorContext
        )

        if
            punctuationNormalized == candidateText,
            let before = editorContext.beforeLastNonWhitespaceCharacter,
            ".!?".contains(before)
        {
            return uppercasingLeadingLetter(in: punctuationNormalized)
        }

        if
            matchesCandidateLettersLoosely(punctuationNormalized, candidateText: candidateText),
            let before = editorContext.beforeLastNonWhitespaceCharacter,
            before.isLetter,
            let after = editorContext.afterFirstNonWhitespaceCharacter,
            after.isLetter,
            looksLikeCapitalizedSentenceStart(punctuationNormalized)
        {
            return lowercasingLeadingLetter(in: stripTerminalPunctuation(from: punctuationNormalized))
        }

        return punctuationNormalized
    }

    private static func uppercasingLeadingLetter(in text: String) -> String {
        guard let firstIndex = text.firstIndex(where: \.isLetter) else {
            return text
        }

        let uppercased = String(text[firstIndex]).uppercased()
        guard uppercased.count == 1, let replacement = uppercased.first else {
            return text
        }

        var result = text
        result.replaceSubrange(firstIndex ... firstIndex, with: [replacement])
        return result
    }

    private static func lowercasingLeadingLetter(in text: String) -> String {
        guard let firstIndex = text.firstIndex(where: \.isLetter) else {
            return text
        }

        let lowercased = String(text[firstIndex]).lowercased()
        guard lowercased.count == 1, let replacement = lowercased.first else {
            return text
        }

        var result = text
        result.replaceSubrange(firstIndex ... firstIndex, with: [replacement])
        return result
    }

    private static func looksLikeCapitalizedSingleWord(_ text: String) -> Bool {
        let words = text.split(whereSeparator: \.isWhitespace)
        guard words.count == 1, let first = words.first else {
            return false
        }

        let word = String(first)
        guard let firstCharacter = word.first, firstCharacter.isUppercase else {
            return false
        }

        let remainder = word.dropFirst()
        return remainder.allSatisfy { !$0.isLetter || $0.isLowercase }
    }

    private static func looksLikeCapitalizedSentenceStart(_ text: String) -> Bool {
        let stripped = stripTerminalPunctuation(from: text)
        return looksLikeCapitalizedSingleWord(stripped)
    }

    private static func stripUnexpectedTerminalPunctuation(
        from adaptedText: String,
        candidateText: String,
        editorContext: FocusedTextContext
    ) -> String {
        guard
            !candidateText.isEmpty,
            !adaptedText.isEmpty,
            !candidateEndsWithTerminalPunctuation(candidateText),
            let before = editorContext.beforeLastNonWhitespaceCharacter,
            before.isLetter,
            let after = editorContext.afterFirstNonWhitespaceCharacter,
            after.isLetter,
            matchesCandidateLettersLoosely(adaptedText, candidateText: candidateText)
        else {
            return adaptedText
        }

        return stripTerminalPunctuation(from: adaptedText)
    }

    private static func candidateEndsWithTerminalPunctuation(_ text: String) -> Bool {
        guard let last = text.last(where: { !isWhitespaceCharacter($0) }) else {
            return false
        }

        return ".!?".contains(last)
    }

    private static func stripTerminalPunctuation(from text: String) -> String {
        var result = text
        while let last = result.last, ".!?".contains(last) {
            result.removeLast()
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func matchesCandidateLettersLoosely(_ adaptedText: String, candidateText: String) -> Bool {
        normalizedLettersOnly(adaptedText) == normalizedLettersOnly(candidateText)
    }

    private static func normalizedLettersOnly(_ text: String) -> String {
        String(text.filter { $0.isLetter }.map { Character(String($0).lowercased()) })
    }

    private func processWithOpenRouter(
        dictatedText: String,
        systemInstructions: String,
        fullPrompt: String,
        configuration: IntelligenceConfiguration
    ) async throws -> IntelligenceProcessingResult {
        guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
            throw IntelligenceError.processingFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.openRouterAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("FriSpeak", forHTTPHeaderField: "X-Title")

        let payload = OpenRouterChatRequest(
            model: configuration.openRouterModel.trimmingCharacters(in: .whitespacesAndNewlines),
            messages: [
                .init(role: "system", content: systemInstructions),
                .init(role: "user", content: fullPrompt)
            ]
        )

        request.httpBody = try JSONEncoder().encode(payload)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw IntelligenceError.processingFailed
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "OpenRouter request failed."
            throw IntelligenceError.remoteError(message)
        }

        let decoded = try JSONDecoder().decode(OpenRouterChatResponse.self, from: data)
        guard let rawResponse = decoded.choices.first?.message.textContent else {
            throw IntelligenceError.processingFailed
        }

        let transformedText = Self.sanitizeModelResponse(rawResponse, fallback: dictatedText)
        return IntelligenceProcessingResult(
            insertedText: transformedText,
            rawModelResponse: rawResponse,
            promptSentToModel: fullPrompt,
            audioDebugSourceURL: nil,
            transportLog: Self.buildTransportLog(
                request: request,
                response: httpResponse,
                responseBody: data
            )
        )
    }

    nonisolated private static func processAudioWithOpenRouter(
        audioURL: URL,
        fullPrompt: String,
        configuration: IntelligenceConfiguration
    ) async throws -> IntelligenceProcessingResult {
        guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
            throw IntelligenceError.processingFailed
        }

        let audioData = try await Self.loadDataOffMainActor(from: audioURL)
        let audioBase64 = audioData.base64EncodedString()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.openRouterAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("FriSpeak", forHTTPHeaderField: "X-Title")

        let dataURI = "data:audio/wav;base64,\(audioBase64)"
        let payload: [String: Any] = [
            "model": configuration.openRouterModel.trimmingCharacters(in: .whitespacesAndNewlines),
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": fullPrompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": dataURI
                            ]
                        ]
                    ]
                ]
            ],
            "temperature": 0,
            "stream": false
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            throw IntelligenceFailureDiagnostic(
                message: "Failed to encode the OpenRouter audio request.",
                promptSentToModel: fullPrompt,
                transportLog: nil
            )
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw IntelligenceFailureDiagnostic(
                message: error.localizedDescription,
                promptSentToModel: fullPrompt,
                transportLog: nil
            )
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw IntelligenceFailureDiagnostic(
                message: "OpenRouter audio request did not return an HTTP response.",
                promptSentToModel: fullPrompt,
                transportLog: nil
            )
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let responsePreview = String(data: data, encoding: .utf8) ?? "OpenRouter audio request failed."
            throw IntelligenceFailureDiagnostic(
                message: responsePreview,
                promptSentToModel: fullPrompt,
                transportLog: Self.buildTransportLog(
                    request: request,
                    response: httpResponse,
                    responseBody: data
                )
            )
        }

        guard let rawResponse = Self.extractOpenRouterTextContent(from: data) else {
            throw IntelligenceError.processingFailed
        }

        let transformedText = Self.sanitizeModelResponse(rawResponse, fallback: "")
        return IntelligenceProcessingResult(
            insertedText: transformedText,
            rawModelResponse: rawResponse,
            promptSentToModel: fullPrompt,
            audioDebugSourceURL: audioURL,
            transportLog: Self.buildTransportLog(
                request: request,
                response: httpResponse,
                responseBody: data
            )
        )
    }

    nonisolated static func sanitizeModelResponse(_ rawResponse: String, fallback: String) -> String {
        var sanitized = rawResponse.trimmingCharacters(in: .newlines)

        sanitized = stripCodeFenceWrapper(from: sanitized)
        sanitized = stripTagLikeWrapper(from: sanitized)
        sanitized = stripPairedWrapper(from: sanitized, prefix: "\"", suffix: "\"")
        sanitized = stripPairedWrapper(from: sanitized, prefix: "'", suffix: "'")
        sanitized = stripPairedWrapper(from: sanitized, prefix: "`", suffix: "`")
        sanitized = stripControlInstructionEcho(from: sanitized)
        sanitized = sanitized.trimmingCharacters(in: .newlines)

        // Detect model refusals / meta-responses and fall back to the original text.
        if looksLikeRefusal(sanitized) {
            return fallback
        }

        if sanitized.isEmpty {
            return fallback
        }

        sanitized = restoreDroppedLeadingDiscourseMarker(in: sanitized, fallback: fallback)
        sanitized = collapseStandaloneSpokenEmojiIfNeeded(in: sanitized, fallback: fallback)
        sanitized = restoreQuestionIntentIfNeeded(in: sanitized, fallback: fallback)
        return sanitized
    }

    nonisolated private static func collapseStandaloneSpokenEmojiIfNeeded(in sanitized: String, fallback: String) -> String {
        guard let emoji = standaloneSpokenEmoji(in: fallback) else {
            return sanitized
        }

        return emoji
    }

    nonisolated private static let standaloneSpokenEmojiAliases: [String: String] = [
        "checkmark": "✓",
        "check mark": "✓",
        "kissing face": "😘",
        "kiss face": "😘",
        "kissy face": "😘",
        "kiss your face": "😘",
        "kiss you face": "😘",
        "smile": "😊",
        "smiley face": "😊",
        "heart eyes": "😍",
        "heart eyes face": "😍",
        "thumbs up": "👍",
        "thumbs down": "👎"
    ]

    nonisolated private static func standaloneSpokenEmoji(in text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let lowered = trimmed.lowercased()
        let cleaned = lowered.replacingOccurrences(
            of: #"^[^a-z0-9]+|[^a-z0-9]+$"#,
            with: "",
            options: .regularExpression
        )

        guard cleaned.hasSuffix(" emoji") else {
            return nil
        }

        let phrase = String(cleaned.dropLast(" emoji".count))
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return standaloneSpokenEmojiAliases[phrase]
    }

    nonisolated private static func restoreQuestionIntentIfNeeded(in sanitized: String, fallback: String) -> String {
        let trimmedFallback = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedFallback.hasSuffix("?"), !trimmedSanitized.isEmpty else {
            return sanitized
        }

        if trimmedSanitized.hasSuffix("?") {
            return sanitized
        }

        return fallback
    }

    nonisolated private static func restoreDroppedLeadingDiscourseMarker(in sanitized: String, fallback: String) -> String {
        let trimmedFallback = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            !trimmedFallback.isEmpty,
            !trimmedSanitized.isEmpty,
            let marker = leadingDiscourseMarker(in: trimmedFallback)
        else {
            return sanitized
        }

        let remainder = trimmedFallback.dropFirst(marker.count).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !remainder.isEmpty else {
            return sanitized
        }

        let normalizedSanitized = normalizeLooseComparisonText(trimmedSanitized)
        let normalizedRemainder = normalizeLooseComparisonText(remainder)
        guard normalizedSanitized == normalizedRemainder else {
            return sanitized
        }

        guard !normalizeLooseComparisonText(trimmedSanitized).hasPrefix(normalizeLooseComparisonText(marker)) else {
            return sanitized
        }

        return marker + " " + trimmedSanitized
    }

    nonisolated private static let preservedLeadingDiscourseMarkers = [
        "whatever",
        "well",
        "so",
        "anyway",
        "anyways",
        "actually",
        "seriously",
        "honestly"
    ]

    nonisolated private static func leadingDiscourseMarker(in text: String) -> String? {
        guard let commaIndex = text.firstIndex(of: ",") else {
            return nil
        }

        let marker = text[..<commaIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !marker.isEmpty else {
            return nil
        }

        let normalizedMarker = marker
            .lowercased()
            .trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespacesAndNewlines))

        guard preservedLeadingDiscourseMarkers.contains(normalizedMarker) else {
            return nil
        }

        return String(text[text.startIndex...commaIndex])
    }

    nonisolated private static func normalizeLooseComparisonText(_ text: String) -> String {
        let scalars = text.unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar) || CharacterSet.whitespacesAndNewlines.contains(scalar)
        }

        let collapsed = String(String.UnicodeScalarView(scalars))
            .lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return collapsed
    }

    nonisolated private static func stripControlInstructionEcho(from text: String) -> String {
        var sanitized = text.trimmingCharacters(in: .whitespacesAndNewlines)

        sanitized = removingTaggedSection(named: "control_instructions", from: sanitized)
        sanitized = removingLeadingInstructionLabel(from: sanitized)

        let markerPatterns = [
            #"(?is)\A.*?</control_instructions>\s*"#,
            #"(?is)\A(?:control instructions|user instructions|instructions|prompt)\s*:\s*.*?(?:\n{2,}|\Z)"#,
            #"(?is)\A(?:here(?:'s| is) the (?:cleaned|transformed|rewritten|final) text)\s*:\s*"#,
            #"(?is)\A(?:output|result|transcription)\s*:\s*"#
        ]

        for pattern in markerPatterns {
            sanitized = sanitized.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
            sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return sanitized
    }

    nonisolated private static func removingTaggedSection(named tagName: String, from text: String) -> String {
        let pattern = #"(?is)<\#(tagName)>\s*.*?\s*</\#(tagName)>\s*"#
        return text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }

    nonisolated private static func removingLeadingInstructionLabel(from text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        guard let firstNonEmptyLine = lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
            return text
        }

        let labelPattern = #"(?i)^\s*(control instructions|user instructions|instructions|prompt)\s*:\s*$"#
        guard firstNonEmptyLine.range(of: labelPattern, options: .regularExpression) != nil else {
            return text
        }

        let remainingLines = Array(lines.drop { $0.trimmingCharacters(in: .whitespaces).isEmpty || $0 == firstNonEmptyLine })
        return remainingLines.joined(separator: "\n")
    }

    /// Detect when a model returns a refusal or meta-commentary instead of
    /// the cleaned transcript. These are much longer than the input and contain
    /// telltale phrases.
    nonisolated private static func looksLikeRefusal(_ text: String) -> Bool {
        let lowered = text.lowercased()
        let refusalPhrases = [
            "i'm sorry",
            "i cannot",
            "i can't",
            "i apologize",
            "as an ai",
            "as a language model",
            "i am not able",
            "i'm not able",
            "it is important to",
            "i must respectfully",
            "i'm unable",
            "cannot provide",
            "cannot assist",
            "feel free to ask",
            "if you have any other",
            "against my guidelines",
            "i don't think i can help"
        ]
        return refusalPhrases.contains(where: { lowered.contains($0) })
    }

    nonisolated private static func stripCodeFenceWrapper(from text: String) -> String {
        guard text.hasPrefix("```"), text.hasSuffix("```") else {
            return text
        }

        let lines = text.components(separatedBy: .newlines)
        guard lines.count >= 2 else {
            return text
        }

        var contentLines = lines
        contentLines.removeFirst()
        if contentLines.last == "```" {
            contentLines.removeLast()
        } else if let lastLine = contentLines.last, lastLine.trimmingCharacters(in: .whitespaces) == "```" {
            contentLines.removeLast()
        }

        return contentLines.joined(separator: "\n")
    }

    nonisolated private static func stripTagLikeWrapper(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            trimmed.hasPrefix("<"),
            let openingEnd = trimmed.firstIndex(of: ">"),
            trimmed.hasSuffix(">"),
            let closingStart = trimmed.lastIndex(of: "<"),
            openingEnd < closingStart
        else {
            return text
        }

        let openingTag = String(trimmed[trimmed.startIndex...openingEnd])
        let closingTag = String(trimmed[closingStart...])

        guard
            openingTag.range(of: #"^<([A-Za-z][A-Za-z0-9:_-]*)>$"#, options: .regularExpression) != nil,
            closingTag.range(of: #"^</([A-Za-z][A-Za-z0-9:_-]*)>$"#, options: .regularExpression) != nil
        else {
            return text
        }

        let contentStart = trimmed.index(after: openingEnd)
        let content = String(trimmed[contentStart..<closingStart])
        return content
    }

    nonisolated private static func stripPairedWrapper(from text: String, prefix: String, suffix: String) -> String {
        guard text.hasPrefix(prefix), text.hasSuffix(suffix), text.count >= prefix.count + suffix.count else {
            return text
        }

        let start = text.index(text.startIndex, offsetBy: prefix.count)
        let end = text.index(text.endIndex, offsetBy: -suffix.count)
        return String(text[start..<end])
    }

    nonisolated private static func buildTransportLog(
        request: URLRequest,
        response: HTTPURLResponse,
        responseBody: Data
    ) -> String {
        let requestID = response.value(forHTTPHeaderField: "x-request-id")
            ?? response.value(forHTTPHeaderField: "request-id")
            ?? response.value(forHTTPHeaderField: "openrouter-request-id")
            ?? "Unavailable"
        let responsePreview = (String(data: responseBody, encoding: .utf8) ?? "Unavailable")
            .prefix(800)

        return """
        Provider Request:
        URL: \(request.url?.absoluteString ?? "Unavailable")
        Method: \(request.httpMethod ?? "POST")
        Timeout: \(Int(request.timeoutInterval))s
        Model Request ID: \(requestID)
        Response Status: \(response.statusCode)

        Provider Response Preview:
        \(responsePreview)
        """
    }

    nonisolated private static func extractOpenRouterTextContent(from data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = object["choices"] as? [[String: Any]],
            let firstChoice = choices.first,
            let message = firstChoice["message"] as? [String: Any]
        else {
            return nil
        }

        if let content = message["content"] as? String {
            return content
        }

        if let parts = message["content"] as? [[String: Any]] {
            return parts.compactMap { $0["text"] as? String }.joined()
        }

        return nil
    }

    nonisolated private static func loadDataOffMainActor(from url: URL) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            try Data(contentsOf: url)
        }.value
    }

}

private struct OpenRouterModelsResponse: Decodable {
    let data: [Model]

    struct Model: Decodable {
        let id: String
        let architecture: Architecture?
        let supportedParameters: [String]?

        struct Architecture: Decodable {
            let inputModalities: [String]?
            let outputModalities: [String]?

            private enum CodingKeys: String, CodingKey {
                case inputModalities = "input_modalities"
                case outputModalities = "output_modalities"
            }
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case architecture
            case supportedParameters = "supported_parameters"
        }
    }
}

struct IntelligenceProcessingResult {
    let insertedText: String
    let rawModelResponse: String
    let promptSentToModel: String
    let audioDebugSourceURL: URL?
    let transportLog: String?
}

struct IntelligenceFailureDiagnostic: LocalizedError {
    let message: String
    let promptSentToModel: String?
    let transportLog: String?

    var errorDescription: String? {
        message
    }
}

private struct OpenRouterChatRequest: Encodable {
    let model: String
    let messages: [Message]

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

private struct OpenRouterChatResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: Content

        var textContent: String {
            content.text
        }
    }

    enum Content: Decodable {
        case text(String)
        case parts([Part])

        struct Part: Decodable {
            let type: String?
            let text: String?
        }

        var text: String {
            switch self {
            case .text(let value):
                return value
            case .parts(let parts):
                return parts.compactMap(\.text).joined()
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                self = .text(string)
                return
            }

            if let parts = try? container.decode([Part].self) {
                self = .parts(parts)
                return
            }

            throw DecodingError.typeMismatch(
                Content.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Unsupported OpenRouter message content.")
            )
        }
    }
}

enum IntelligenceError: LocalizedError {
    case modelUnavailable
    case processingFailed
    case appleIntelligenceUnavailable(String)
    case localModelUnavailable(String)
    case remoteError(String)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "No configured intelligence provider is available."
        case .processingFailed:
            return "Failed to process text with the selected model."
        case .appleIntelligenceUnavailable(let message):
            return message
        case .localModelUnavailable(let message):
            return message
        case .remoteError(let message):
            return message
        }
    }
}

extension Error {
    var frispeakReadableMessage: String {
        if let diagnostic = self as? IntelligenceFailureDiagnostic {
            return diagnostic.message
        }

        if let urlError = self as? URLError {
            switch urlError.code {
            case .timedOut:
                return "The model request timed out before the provider returned a response."
            case .cancelled:
                return "The request was canceled."
            case .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
                return "The network connection failed while contacting the model provider."
            default:
                return urlError.localizedDescription
            }
        }

        if let generationError = self as? LanguageModelSession.GenerationError {
            return generationError.localizedDescription
        }

        return localizedDescription
    }
}

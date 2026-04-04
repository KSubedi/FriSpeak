import XCTest
@testable import FriSpeak

final class IntelligencePipelineTests: XCTestCase {
    func testSanitizeModelResponseFallsBackWhenModelAnswersQuestion() {
        let sanitized = IntelligenceService.sanitizeModelResponse(
            "I'm doing well, thank you.",
            fallback: "How are you doing today?"
        )

        XCTAssertEqual(sanitized, "How are you doing today?")
    }

    func testSanitizeModelResponseRestoresDroppedLeadingDiscourseMarker() {
        let sanitized = IntelligenceService.sanitizeModelResponse(
            "I might actually show up.",
            fallback: "Whatever, I might actually show up."
        )

        XCTAssertEqual(sanitized, "Whatever, I might actually show up.")
    }

    func testSanitizeModelResponseCollapsesStandaloneSpokenEmoji() {
        let sanitized = IntelligenceService.sanitizeModelResponse(
            "Kiss you face 😘.",
            fallback: "Kiss you face emoji."
        )

        XCTAssertEqual(sanitized, "😘")
    }

    func testSanitizeModelResponseStripsInstructionEcho() {
        let rawResponse = """
        User instructions: Preserve echowin.

        Here is the cleaned text: echowin ships today.
        """

        let sanitized = IntelligenceService.sanitizeModelResponse(
            rawResponse,
            fallback: "echowin ships today"
        )

        XCTAssertEqual(sanitized, "echowin ships today.")
    }

    func testSanitizeAdaptedInsertionRemovesCopiedAfterContext() {
        let context = makeContext(
            before: "The package is",
            after: " here."
        )

        let sanitized = IntelligenceService.sanitizeAdaptedInsertion(
            "Finally. here.",
            candidateText: "Finally.",
            editorContext: context
        )

        XCTAssertEqual(sanitized, "finally")
    }

    func testLocalBonsaiCleanupTokenBudgetScalesButStaysBounded() {
        let shortPrompt = "clean this sentence"
        let longPrompt = String(repeating: "word ", count: 500)

        XCTAssertEqual(
            LocalBonsaiIntelligenceService.maxTokens(for: shortPrompt, taskKind: .cleanup),
            64
        )
        XCTAssertEqual(
            LocalBonsaiIntelligenceService.maxTokens(for: longPrompt, taskKind: .cleanup),
            192
        )
    }

    func testLocalBonsaiInsertionTokenBudgetIsSmallerThanCleanupBudget() {
        let prompt = String(repeating: "word ", count: 40)

        let cleanupBudget = LocalBonsaiIntelligenceService.maxTokens(for: prompt, taskKind: .cleanup)
        let insertionBudget = LocalBonsaiIntelligenceService.maxTokens(for: prompt, taskKind: .insertionAdaptation)

        XCTAssertLessThan(insertionBudget, cleanupBudget)
        XCTAssertEqual(insertionBudget, 52)
    }

    private func makeContext(
        before: String,
        selected: String = "",
        after: String
    ) -> FocusedTextContext {
        let fullText = before + selected + after
        return FocusedTextContext(
            applicationName: "Arc",
            fullText: fullText,
            caretLocation: before.utf16.count,
            selectedLength: selected.utf16.count,
            textBeforeSelection: before,
            selectedText: selected,
            textAfterSelection: after
        )
    }
}

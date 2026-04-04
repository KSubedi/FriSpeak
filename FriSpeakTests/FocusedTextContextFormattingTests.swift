import XCTest
@testable import FriSpeak

final class FocusedTextContextFormattingTests: XCTestCase {
    func testAddsSpacesBetweenWordBoundaries() {
        let context = makeContext(before: "hello", after: "world")

        XCTAssertEqual(context.formatForInsertion("there"), " there ")
    }

    func testDoesNotForceLowercaseProperNoun() {
        let context = makeContext(before: "hello ", after: "")

        XCTAssertEqual(context.formatForInsertion("OpenAI"), "OpenAI")
    }

    func testDoesNotAddSpaceInsideParentheses() {
        let context = makeContext(before: "(", after: ")")

        XCTAssertEqual(context.formatForInsertion("test"), "test")
    }

    func testDoesNotAddSpaceBeforeClosingPunctuation() {
        let context = makeContext(before: "hello", after: ", world")

        XCTAssertEqual(context.formatForInsertion("there"), " there")
    }

    func testRemovesDuplicatedLeadingPunctuationAtBoundary() {
        let context = makeContext(before: "hello,", after: "")

        XCTAssertEqual(context.formatForInsertion(", there"), " there")
    }

    func testRemovesDuplicatedTrailingPunctuationAtBoundary() {
        let context = makeContext(before: "hello", after: ".")

        XCTAssertEqual(context.formatForInsertion("."), "")
    }

    func testDoesNotAddSpacesInsideQuotes() {
        let context = makeContext(before: "He said, \"", after: "\"")

        XCTAssertEqual(context.formatForInsertion("hello"), "hello")
    }

    func testPreservesModelProvidedLeadingSpaceWhenItAlreadyFits() {
        let context = makeContext(before: "Marketing & Automation", after: "")

        XCTAssertEqual(context.formatForInsertion(" and IT Agencies."), " and IT Agencies.")
    }

    func testAddsSpaceWhenEditorUsesZeroWidthPlaceholderBoundaryCharacters() {
        let zeroWidthSpace = "\u{200B}"
        let context = makeContext(
            before: "Marketing & Automation\(zeroWidthSpace)",
            after: zeroWidthSpace
        )

        XCTAssertEqual(context.formatForInsertion("and IT companies"), " and IT companies")
    }

    func testHiddenBeforeContextForcesLeadingSpaceFallback() {
        let zeroWidthSpace = "\u{200B}"
        let context = makeContext(
            before: String(repeating: zeroWidthSpace, count: 3),
            after: ""
        )

        XCTAssertTrue(context.lacksUsableVisibleBoundaryContext)
        XCTAssertEqual(context.formatForInsertion("and IT companies and"), " and IT companies and")
    }

    func testHiddenBeforeContextNormalizesContinuationFragment() {
        let zeroWidthSpace = "\u{200B}"
        let context = makeContext(
            before: String(repeating: zeroWidthSpace, count: 2),
            after: ""
        )

        XCTAssertEqual(context.formatForInsertion("By optimizing."), " by optimizing")
    }

    func testIgnoresShortLabelLikeBoundaryContextForLeadingSpace() {
        let context = makeContext(
            before: "Ask Gemini 3",
            after: "\n",
            applicationName: "Arc"
        )

        XCTAssertEqual(context.textBeforeSelectionExcerpt, "")
        XCTAssertEqual(context.formatForInsertion("Does Android support passkeys?"), "Does Android support passkeys?")
    }

    func testSkipsModelInsertionAdaptationAtStartOfEmptyField() {
        let context = makeContext(before: "", after: "")

        XCTAssertTrue(context.shouldSkipModelInsertionAdaptation)
    }

    func testSkipsModelInsertionAdaptationWhenWhitespaceAlreadySeparatesBoundary() {
        let context = makeContext(before: "hello ", after: "world")

        XCTAssertTrue(context.shouldSkipModelInsertionAdaptation)
    }

    func testKeepsModelInsertionAdaptationForMidWordBoundary() {
        let context = makeContext(before: "hello", after: "world")

        XCTAssertFalse(context.shouldSkipModelInsertionAdaptation)
    }

    func testInsertionPromptSectionIncludesBoundaryFactsAndSelection() {
        let context = makeContext(
            before: "hello ",
            selected: "world",
            after: "!",
            applicationName: "Notes"
        )

        let section = context.insertionPromptSection

        XCTAssertTrue(section.contains("<mode>replace_selection</mode>"))
        XCTAssertTrue(section.contains("<before_excerpt>hello </before_excerpt>"))
        XCTAssertTrue(section.contains("<selected_excerpt>world</selected_excerpt>"))
        XCTAssertTrue(section.contains("<after_excerpt>!</after_excerpt>"))
        XCTAssertTrue(section.contains("<before_last_non_whitespace_character>o</before_last_non_whitespace_character>"))
        XCTAssertTrue(section.contains("<after_first_non_whitespace_character>!</after_first_non_whitespace_character>"))
    }

    func testSanitizeAdaptedInsertionRemovesInventedLeadingSentencePunctuation() {
        let context = makeContext(before: "Ask Gemini 3", after: "\n")

        let sanitized = IntelligenceService.sanitizeAdaptedInsertion(
            ". Does Android support using 1Password for passkeys, similarly to how iOS does?",
            candidateText: "Does Android support using One Password for passkeys, kind of like how iOS does?",
            editorContext: context
        )

        XCTAssertEqual(sanitized, "Does Android support using 1Password for passkeys, similarly to how iOS does?")
    }

    private func makeContext(
        before: String,
        selected: String = "",
        after: String,
        applicationName: String? = nil
    ) -> FocusedTextContext {
        let fullText = before + selected + after
        return FocusedTextContext(
            applicationName: applicationName,
            fullText: fullText,
            caretLocation: before.utf16.count,
            selectedLength: selected.utf16.count,
            textBeforeSelection: before,
            selectedText: selected,
            textAfterSelection: after
        )
    }
}

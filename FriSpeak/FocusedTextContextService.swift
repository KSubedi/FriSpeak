//
//  FocusedTextContextService.swift
//  FriSpeak
//

import AppKit
import ApplicationServices
import Foundation

struct FocusedTextContext {
    private static let contextExcerptLimit = 250

    let applicationName: String?
    let fullText: String
    let caretLocation: Int
    let selectedLength: Int
    let textBeforeSelection: String
    let selectedText: String
    let textAfterSelection: String

    var hasSelection: Bool {
        selectedLength > 0
    }

    private var normalizedTextBeforeSelection: String {
        removingIgnorableBoundaryCharacters(from: textBeforeSelection)
    }

    private var normalizedSelectedText: String {
        removingIgnorableBoundaryCharacters(from: selectedText)
    }

    private var normalizedTextAfterSelection: String {
        removingIgnorableBoundaryCharacters(from: textAfterSelection)
    }

    private var effectiveNormalizedTextBeforeSelection: String {
        shouldIgnoreBeforeBoundaryContext ? "" : normalizedTextBeforeSelection
    }

    private var effectiveNormalizedTextAfterSelection: String {
        normalizedTextAfterSelection
    }

    private var shouldIgnoreBeforeBoundaryContext: Bool {
        guard !hasSelection else {
            return false
        }

        let trimmedBefore = normalizedTextBeforeSelection.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBefore.isEmpty else {
            return false
        }

        let trimmedAfter = normalizedTextAfterSelection.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedAfter.isEmpty, normalizedTextAfterSelection.contains("\n") else {
            return false
        }

        guard !trimmedBefore.contains("\n") else {
            return false
        }

        let words = trimmedBefore.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty, words.count <= 4 else {
            return false
        }

        guard !trimmedBefore.contains(where: { ".!?,;:".contains($0) }) else {
            return false
        }

        // Treat short single-line label-like prefixes followed only by a
        // newline as non-document UI context rather than editable text.
        return words.contains(where: \.containsLetter) || trimmedBefore.contains(where: \.isNumber)
    }

    var textBeforeSelectionExcerpt: String {
        trailingExcerpt(of: effectiveNormalizedTextBeforeSelection, limit: Self.contextExcerptLimit)
    }

    var textAfterSelectionExcerpt: String {
        leadingExcerpt(of: effectiveNormalizedTextAfterSelection, limit: Self.contextExcerptLimit)
    }

    var hasOmittedTextBeforeSelection: Bool {
        textBeforeSelection.count > textBeforeSelectionExcerpt.count
    }

    var hasOmittedTextAfterSelection: Bool {
        textAfterSelection.count > textAfterSelectionExcerpt.count
    }

    var hasHiddenContextBeforeSelection: Bool {
        !textBeforeSelection.isEmpty && normalizedTextBeforeSelection.isEmpty
    }

    var hasHiddenContextAfterSelection: Bool {
        !textAfterSelection.isEmpty && normalizedTextAfterSelection.isEmpty
    }

    var lacksUsableVisibleBoundaryContext: Bool {
        hasHiddenContextBeforeSelection || hasHiddenContextAfterSelection
    }

    var fullTextExcerpt: String {
        excerptAroundSelection(of: fullText, caretLocation: caretLocation, selectedLength: selectedLength, limit: Self.contextExcerptLimit)
    }

    var hasOmittedFullText: Bool {
        fullText.count > fullTextExcerpt.count
    }

    var caretIsAtLineStart: Bool {
        guard let previousCharacter = effectiveNormalizedTextBeforeSelection.last else {
            return true
        }

        return previousCharacter == "\n"
    }

    var caretIsAfterBlankLine: Bool {
        effectiveNormalizedTextBeforeSelection.hasSuffix("\n\n")
    }

    var selectionSpansMultipleLines: Bool {
        normalizedSelectedText.contains("\n")
    }

    var beforeEndsWithBlankLine: Bool {
        textBeforeSelectionExcerpt.hasSuffix("\n\n")
    }

    var afterStartsWithBlankLine: Bool {
        textAfterSelectionExcerpt.hasPrefix("\n\n")
    }

    var beforeLineIndentation: String {
        indentationPrefix(in: currentLinePrefixBeforeCaret)
    }

    var afterLineIndentation: String {
        indentationPrefix(in: currentLinePrefixAfterCaret)
    }

    var beforeLastNonWhitespaceCharacter: Character? {
        effectiveNormalizedTextBeforeSelection.last(where: { !$0.isWhitespace })
    }

    var afterFirstNonWhitespaceCharacter: Character? {
        effectiveNormalizedTextAfterSelection.first(where: { !$0.isWhitespace })
    }

    var beforeMayNeedTerminalPunctuation: Bool {
        let trimmedBefore = effectiveNormalizedTextBeforeSelection.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let lastCharacter = trimmedBefore.last,
            lastCharacter.isLetter
        else {
            // Numbers, symbols, or empty text don't signal an unterminated sentence.
            return false
        }

        let lastLine = trimmedBefore.components(separatedBy: .newlines).last ?? trimmedBefore
        let words = lastLine.split(whereSeparator: \.isWhitespace)

        // Require a substantial sentence (6+ words) to be confident this is
        // a real unterminated sentence rather than a title, placeholder, label, etc.
        return words.count >= 6
    }

    var shouldSkipModelInsertionAdaptation: Bool {
        guard !hasSelection else {
            return false
        }

        if lacksUsableVisibleBoundaryContext {
            return true
        }

        if beforeLastNonWhitespaceCharacter == nil || afterFirstNonWhitespaceCharacter == nil {
            return true
        }

        if caretIsAtLineStart || caretIsAfterBlankLine {
            return true
        }

        if effectiveNormalizedTextBeforeSelection.last?.isWhitespace == true
            || effectiveNormalizedTextAfterSelection.first?.isWhitespace == true {
            return true
        }

        guard
            let before = beforeLastNonWhitespaceCharacter,
            let after = afterFirstNonWhitespaceCharacter
        else {
            return true
        }

        if isOpeningBracketOrQuote(before) || isClosingBracketOrQuote(after) {
            return true
        }

        if isJoinPunctuation(before) || isJoinPunctuation(after) {
            return true
        }

        return false
    }

    var promptSection: String? {
        // Surrounding text gives the LLM semantic context (topic, tone, style).
        // Formatting/joining is handled programmatically so we omit those fields.
        let before = textBeforeSelectionExcerpt
        let selected = normalizedSelectedText
        let after = textAfterSelectionExcerpt
        guard !before.isEmpty || !selected.isEmpty || !after.isEmpty else {
            return nil
        }
        var parts = [String]()
        parts.append("<mode>\(hasSelection ? "replace_selection" : "insert_at_caret")</mode>")
        if !before.isEmpty { parts.append("<before>\(before)</before>") }
        if !selected.isEmpty { parts.append("<selected>\(selected)</selected>") }
        if !after.isEmpty { parts.append("<after>\(after)</after>") }
        return parts.joined(separator: "\n")
    }

    var insertionPromptSection: String {
        let before = xmlEscaped(textBeforeSelectionExcerpt)
        let selected = xmlEscaped(normalizedSelectedText)
        let after = xmlEscaped(textAfterSelectionExcerpt)

        return """
        <insertion_context>
        <mode>\(hasSelection ? "replace_selection" : "insert_at_caret")</mode>
        <boundary_facts>
        <caret_is_at_line_start>\(caretIsAtLineStart ? "yes" : "no")</caret_is_at_line_start>
        <caret_is_after_blank_line>\(caretIsAfterBlankLine ? "yes" : "no")</caret_is_after_blank_line>
        <selection_spans_multiple_lines>\(selectionSpansMultipleLines ? "yes" : "no")</selection_spans_multiple_lines>
        <before_last_character>\(xmlEscaped(boundaryCharacterDescription(effectiveNormalizedTextBeforeSelection.last)))</before_last_character>
        <before_last_non_whitespace_character>\(xmlEscaped(boundaryCharacterDescription(beforeLastNonWhitespaceCharacter)))</before_last_non_whitespace_character>
        <after_first_character>\(xmlEscaped(boundaryCharacterDescription(effectiveNormalizedTextAfterSelection.first)))</after_first_character>
        <after_first_non_whitespace_character>\(xmlEscaped(boundaryCharacterDescription(afterFirstNonWhitespaceCharacter)))</after_first_non_whitespace_character>
        <before_may_need_terminal_punctuation>\(beforeMayNeedTerminalPunctuation ? "yes" : "no")</before_may_need_terminal_punctuation>
        <before_context_hidden>\(hasHiddenContextBeforeSelection ? "yes" : "no")</before_context_hidden>
        <after_context_hidden>\(hasHiddenContextAfterSelection ? "yes" : "no")</after_context_hidden>
        <before_line_indent>\(xmlEscaped(visibleWhitespaceDescription(beforeLineIndentation)))</before_line_indent>
        <after_line_indent>\(xmlEscaped(visibleWhitespaceDescription(afterLineIndentation)))</after_line_indent>
        </boundary_facts>
        <before_excerpt>\(before)</before_excerpt>
        <selected_excerpt>\(selected)</selected_excerpt>
        <after_excerpt>\(after)</after_excerpt>
        </insertion_context>
        """
    }

    /// Conservative boundary cleanup after the insertion-adaptation pass.
    /// It removes impossible duplicated boundary punctuation and adds only the
    /// whitespace that is obviously required by the surrounding text.
    func formatForInsertion(_ text: String) -> String {
        guard !text.isEmpty else { return text }

        var result = normalizeHiddenContextContinuationIfNeeded(in: text)
        result = normalizeVisibleContextContinuationIfNeeded(in: result)
        result = reconcileLeadingBoundary(of: result)
        result = reconcileTrailingBoundary(of: result)
        let prefix = requiredLeadingWhitespace(for: result)
        let suffix = requiredTrailingWhitespace(for: result)
        return prefix + result + suffix
    }

    private func normalizeHiddenContextContinuationIfNeeded(in text: String) -> String {
        guard hasHiddenContextBeforeSelection else {
            return text
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return text
        }

        guard let firstWord = trimmed.split(whereSeparator: \.isWhitespace).first else {
            return text
        }

        let lowercasedFirstWord = firstWord.lowercased()
        guard Self.hiddenContextContinuationStarters.contains(lowercasedFirstWord) else {
            return text
        }

        var normalized = trimmed
        if let last = normalized.last, ".!?".contains(last) {
            normalized.removeLast()
        }

        normalized = lowercasingLeadingLetter(in: normalized)

        let preservedLeadingWhitespace = String(text.prefix { $0.isWhitespace })
        let preservedTrailingWhitespace = String(text.reversed().prefix { $0.isWhitespace }.reversed())
        return preservedLeadingWhitespace + normalized + preservedTrailingWhitespace
    }

    private func normalizeVisibleContextContinuationIfNeeded(in text: String) -> String {
        guard !selectionSpansMultipleLines else {
            return text
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return text
        }

        let replacingInlineSelection: Bool = {
            guard hasSelection, let before = beforeLastNonWhitespaceCharacter, before.isLetter else {
                return false
            }

            guard let after = afterFirstNonWhitespaceCharacter else {
                return false
            }

            return after.isLetter || ".!?,;:".contains(after)
        }()

        let replacingLowercaseSelection = hasSelection && selectedTextStartsWithLowercaseLetter
        let continuingBetweenWords: Bool = {
            guard
                let before = beforeLastNonWhitespaceCharacter,
                before.isLetter,
                let after = afterFirstNonWhitespaceCharacter,
                after.isLetter
            else {
                return false
            }

            return true
        }()

        guard replacingInlineSelection || replacingLowercaseSelection || continuingBetweenWords else {
            return text
        }

        var normalized = trimmed
        if let last = normalized.last, ".!?".contains(last) {
            normalized.removeLast()
        }

        guard !normalized.isEmpty else {
            return text
        }

        if shouldLowercaseLeadingLetterForVisibleContinuation(normalized) {
            normalized = lowercasingLeadingLetter(in: normalized)
        }

        let preservedLeadingWhitespace = String(text.prefix { $0.isWhitespace })
        let preservedTrailingWhitespace = String(text.reversed().prefix { $0.isWhitespace }.reversed())
        return preservedLeadingWhitespace + normalized + preservedTrailingWhitespace
    }

    private var selectedTextStartsWithLowercaseLetter: Bool {
        guard let firstLetter = normalizedSelectedText.first(where: \.isLetter) else {
            return false
        }

        return firstLetter.isLowercase
    }

    private func shouldLowercaseLeadingLetterForVisibleContinuation(_ text: String) -> Bool {
        guard let firstIndex = text.firstIndex(where: \.isLetter) else {
            return false
        }

        let firstCharacter = text[firstIndex]
        guard firstCharacter.isUppercase else {
            return false
        }

        let remainder = text[text.index(after: firstIndex)...]
        return !remainder.contains(where: \.isUppercase)
    }

    private func lowercasingLeadingLetter(in text: String) -> String {
        guard let firstIndex = text.firstIndex(where: \.isLetter) else {
            return text
        }

        let character = text[firstIndex]
        let lowercased = String(character).lowercased()
        guard lowercased.count == 1, let replacement = lowercased.first else {
            return text
        }

        var result = text
        result.replaceSubrange(firstIndex ... firstIndex, with: [replacement])
        return result
    }

    private func reconcileLeadingBoundary(of text: String) -> String {
        guard
            let firstIndex = text.firstIndex(where: { !$0.isWhitespace }),
            let firstCharacter = nonWhitespaceCharacter(in: text, fromStart: true)
        else {
            return text
        }

        var result = text

        // Drop punctuation that only makes sense when directly attached to the
        // left-hand text, but the caret is currently at a whitespace/start boundary.
        if isJoinPunctuation(firstCharacter),
           !canAttachLeadingPunctuationToLeftBoundary {
            result.remove(at: firstIndex)
            return result.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Avoid duplicated punctuation across the caret boundary.
        if let before = beforeLastNonWhitespaceCharacter,
           isJoinPunctuation(before),
           isJoinPunctuation(firstCharacter),
           punctuationRole(before) == punctuationRole(firstCharacter) {
            result.remove(at: firstIndex)
        }

        return result
    }

    private func reconcileTrailingBoundary(of text: String) -> String {
        guard
            let lastIndex = text.lastIndex(where: { !$0.isWhitespace }),
            let lastCharacter = nonWhitespaceCharacter(in: text, fromStart: false)
        else {
            return text
        }

        var result = text

        if let after = afterFirstNonWhitespaceCharacter,
           isJoinPunctuation(lastCharacter),
           isJoinPunctuation(after),
           punctuationRole(lastCharacter) == punctuationRole(after) {
            result.remove(at: lastIndex)
        }

        return result
    }

    private var canAttachLeadingPunctuationToLeftBoundary: Bool {
        guard let before = beforeLastNonWhitespaceCharacter else {
            return false
        }

        if effectiveNormalizedTextBeforeSelection.last?.isWhitespace == true {
            return false
        }

        return before.isLetter
            || before.isNumber
            || isClosingBracketOrQuote(before)
    }

    private func requiredLeadingWhitespace(for text: String) -> String {
        if hasHiddenContextBeforeSelection,
           text.first?.isWhitespace != true,
           let first = nonWhitespaceCharacter(in: text, fromStart: true),
           isWordLike(first) {
            return " "
        }

        guard
            text.first?.isWhitespace != true,
            effectiveNormalizedTextBeforeSelection.last?.isWhitespace != true,
            let before = beforeLastNonWhitespaceCharacter,
            let first = nonWhitespaceCharacter(in: text, fromStart: true)
        else {
            return ""
        }

        if isJoinPunctuation(first) || isClosingBracketOrQuote(first) {
            return ""
        }

        if isOpeningBracketOrQuote(before) {
            return ""
        }

        if needsSpaceBetween(left: before, right: first) {
            return " "
        }

        return ""
    }

    private func requiredTrailingWhitespace(for text: String) -> String {
        guard
            text.last?.isWhitespace != true,
            effectiveNormalizedTextAfterSelection.first?.isWhitespace != true,
            let last = nonWhitespaceCharacter(in: text, fromStart: false),
            let after = afterFirstNonWhitespaceCharacter
        else {
            return ""
        }

        if isOpeningBracketOrQuote(after) || isClosingPunctuation(after) {
            return ""
        }

        if needsSpaceBetween(left: last, right: after) {
            return " "
        }

        return ""
    }

    private func needsSpaceBetween(left: Character, right: Character) -> Bool {
        if isOpeningBracketOrQuote(left) || isJoinPunctuation(right) || isClosingBracketOrQuote(right) {
            return false
        }

        if isWordLike(left) && isWordLike(right) {
            return true
        }

        if isJoinPunctuation(left) && isWordLike(right) {
            return true
        }

        if isClosingBracketOrQuote(left) && isWordLike(right) {
            return true
        }

        return false
    }

    private func nonWhitespaceCharacter(in text: String, fromStart: Bool) -> Character? {
        if fromStart {
            return text.first(where: { !$0.isWhitespace })
        }

        return text.last(where: { !$0.isWhitespace })
    }

    private func isOpeningBracketOrQuote(_ ch: Character) -> Bool {
        ch == "(" || ch == "[" || ch == "{" || ch == "\"" || ch == "'" || ch == "\u{201C}" || ch == "\u{2018}"
    }

    private func isClosingBracketOrQuote(_ ch: Character) -> Bool {
        ch == ")" || ch == "]" || ch == "}" || ch == "\"" || ch == "'" || ch == "\u{201D}" || ch == "\u{2019}"
    }

    private func isJoinPunctuation(_ ch: Character) -> Bool {
        punctuationRole(ch) != .none
    }

    private func isClosingPunctuation(_ ch: Character) -> Bool {
        switch punctuationRole(ch) {
        case .sentenceTerminal, .separator:
            return true
        case .none:
            return false
        }
    }

    private func isWordLike(_ ch: Character) -> Bool {
        ch.isLetter || ch.isNumber
    }

    private func punctuationRole(_ ch: Character) -> PunctuationRole {
        switch ch {
        case ".", "!", "?":
            return .sentenceTerminal
        case ",", ";", ":":
            return .separator
        default:
            return .none
        }
    }

    var audioPromptSection: String {
        """
        Editor context:
        - app: \(applicationName ?? "Unknown")
        - mode: \(hasSelection ? "replace_selection" : "insert_at_caret")
        - caret_is_at_line_start: \(caretIsAtLineStart ? "yes" : "no")
        - caret_is_after_blank_line: \(caretIsAfterBlankLine ? "yes" : "no")
        - selection_spans_multiple_lines: \(selectionSpansMultipleLines ? "yes" : "no")
        - before_last_character: \(boundaryCharacterDescription(effectiveNormalizedTextBeforeSelection.last))
        - before_last_non_whitespace_character: \(boundaryCharacterDescription(beforeLastNonWhitespaceCharacter))
        - before_may_need_terminal_punctuation: \(beforeMayNeedTerminalPunctuation ? "yes" : "no")
        - after_first_character: \(boundaryCharacterDescription(effectiveNormalizedTextAfterSelection.first))
        - before_line_indent: \(visibleWhitespaceDescription(beforeLineIndentation))
        - after_line_indent: \(visibleWhitespaceDescription(afterLineIndentation))
        - selected_preview: \(selectionPreview)
        """
    }

    private func trailingExcerpt(of text: String, limit: Int) -> String {
        guard text.count > limit else {
            return text
        }

        return String(text.suffix(limit))
    }

    private var selectionPreview: String {
        let trimmed = normalizedSelectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "none"
        }

        return String(trimmed.prefix(80))
    }

    private func leadingExcerpt(of text: String, limit: Int) -> String {
        guard text.count > limit else {
            return text
        }

        return String(text.prefix(limit))
    }

    private func excerptAroundSelection(of text: String, caretLocation: Int, selectedLength: Int, limit: Int) -> String {
        let nsText = text as NSString
        let totalLength = nsText.length
        guard totalLength > limit else {
            return text
        }

        let selectionEnd = min(totalLength, caretLocation + selectedLength)
        let selectionCenter = (caretLocation + selectionEnd) / 2
        let halfWindow = limit / 2
        var start = max(0, selectionCenter - halfWindow)
        let end = min(totalLength, start + limit)

        if end - start < limit {
            start = max(0, end - limit)
        }

        return nsText.substring(with: NSRange(location: start, length: end - start))
    }

    private var currentLinePrefixBeforeCaret: String {
        guard let lastNewlineIndex = effectiveNormalizedTextBeforeSelection.lastIndex(of: "\n") else {
            return effectiveNormalizedTextBeforeSelection
        }

        let nextIndex = effectiveNormalizedTextBeforeSelection.index(after: lastNewlineIndex)
        return String(effectiveNormalizedTextBeforeSelection[nextIndex...])
    }

    private var currentLinePrefixAfterCaret: String {
        guard let firstNewlineIndex = effectiveNormalizedTextAfterSelection.firstIndex(of: "\n") else {
            return effectiveNormalizedTextAfterSelection
        }

        return String(effectiveNormalizedTextAfterSelection[..<firstNewlineIndex])
    }

    private func indentationPrefix(in lineFragment: String) -> String {
        let indentation = lineFragment.prefix { $0 == " " || $0 == "\t" }
        return String(indentation)
    }

    private func boundaryCharacterDescription(_ character: Character?) -> String {
        guard let character else {
            return "none"
        }

        switch character {
        case " ":
            return "space"
        case "\n":
            return "newline"
        case "\t":
            return "tab"
        default:
            return String(character)
        }
    }

    private func visibleWhitespaceDescription(_ value: String) -> String {
        if value.isEmpty {
            return "none"
        }

        return value
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: " ", with: "·")
    }

    private func xmlEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func removingIgnorableBoundaryCharacters(from value: String) -> String {
        String(value.filter { !$0.isIgnorableBoundaryCharacter })
    }
}

private enum PunctuationRole {
    case none
    case separator
    case sentenceTerminal
}

private extension FocusedTextContext {
    static let hiddenContextContinuationStarters: Set<String> = [
        "and", "as", "because", "but", "by", "for", "if", "in", "or",
        "so", "then", "to", "when", "while", "with", "without"
    ]
}

private extension Character {
    var isWhitespace: Bool {
        unicodeScalars.allSatisfy(CharacterSet.whitespacesAndNewlines.contains)
    }

    var isIgnorableBoundaryCharacter: Bool {
        unicodeScalars.allSatisfy {
            switch $0.value {
            case 0x200B, 0x200C, 0x200D, 0x2060, 0xFEFF:
                return true
            default:
                return false
            }
        }
    }
}

private extension String {
    var isOnlyIgnorableBoundaryCharacters: Bool {
        !isEmpty && allSatisfy(\.isIgnorableBoundaryCharacter)
    }
}

private extension Substring {
    var containsLetter: Bool {
        contains(where: \.isLetter)
    }
}

struct FocusedTextContextService {
    func currentContext() -> FocusedTextContext? {
        let systemWideElement = AXUIElementCreateSystemWide()

        guard let focusedElement = copyElementAttribute(kAXFocusedUIElementAttribute as CFString, from: systemWideElement) else {
            return nil
        }

        if let valueText = copyStringAttribute(kAXValueAttribute as CFString, from: focusedElement),
           !valueText.isOnlyIgnorableBoundaryCharacters {
            let range = copySelectedRange(from: focusedElement) ?? CFRange(location: valueText.utf16.count, length: 0)
            let clampedRange = clamp(range: range, toUTF16Length: valueText.utf16.count)
            let components = split(fullText: valueText, around: clampedRange)

            return FocusedTextContext(
                applicationName: NSWorkspace.shared.frontmostApplication?.localizedName,
                fullText: valueText,
                caretLocation: clampedRange.location,
                selectedLength: clampedRange.length,
                textBeforeSelection: components.before,
                selectedText: components.selected,
                textAfterSelection: components.after
            )
        }

        return currentContextUsingParameterizedRanges(from: focusedElement)
    }

    private func copyElementAttribute(_ attribute: CFString, from element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let value else {
            return nil
        }

        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private func copyStringAttribute(_ attribute: CFString, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let value else {
            return nil
        }

        if let string = value as? String {
            return string
        }

        if let attributedString = value as? NSAttributedString {
            return attributedString.string
        }

        return nil
    }

    private func copySelectedRange(from element: AXUIElement) -> CFRange? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &value)
        guard result == .success,
              let axValue = value,
              CFGetTypeID(axValue) == AXValueGetTypeID()
        else {
            return nil
        }

        let rangeValue = unsafeBitCast(axValue, to: AXValue.self)
        guard AXValueGetType(rangeValue) == .cfRange else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(rangeValue, .cfRange, &range) else {
            return nil
        }

        return range
    }

    private func copyIntAttribute(_ attribute: CFString, from element: AXUIElement) -> Int? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let value else {
            return nil
        }

        if let number = value as? NSNumber {
            return number.intValue
        }

        return nil
    }

    private func copyStringForRange(_ range: CFRange, from element: AXUIElement) -> String? {
        var axRange = range
        guard let rangeValue = AXValueCreate(.cfRange, &axRange) else {
            return nil
        }

        var value: CFTypeRef?
        let result = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXStringForRangeParameterizedAttribute as CFString,
            rangeValue,
            &value
        )
        guard result == .success, let value else {
            return nil
        }

        if let string = value as? String {
            return string
        }

        if let attributedString = value as? NSAttributedString {
            return attributedString.string
        }

        return nil
    }

    private func currentContextUsingParameterizedRanges(from element: AXUIElement) -> FocusedTextContext? {
        let totalLength = copyIntAttribute(kAXNumberOfCharactersAttribute as CFString, from: element) ?? 0
        guard totalLength >= 0 else {
            return nil
        }

        let selectedRange = copySelectedRange(from: element) ?? CFRange(location: totalLength, length: 0)
        let clampedRange = clamp(range: selectedRange, toUTF16Length: totalLength)

        let beforeStart = max(0, clampedRange.location - 250)
        let beforeLength = max(0, clampedRange.location - beforeStart)
        let afterStart = min(totalLength, clampedRange.location + clampedRange.length)
        let afterLength = min(250, max(0, totalLength - afterStart))

        let before = copyStringForRange(CFRange(location: beforeStart, length: beforeLength), from: element) ?? ""
        let selected = copyStringForRange(clampedRange, from: element) ?? ""
        let after = copyStringForRange(CFRange(location: afterStart, length: afterLength), from: element) ?? ""

        guard !before.isEmpty || !selected.isEmpty || !after.isEmpty else {
            return nil
        }

        return FocusedTextContext(
            applicationName: NSWorkspace.shared.frontmostApplication?.localizedName,
            fullText: before + selected + after,
            caretLocation: before.utf16.count,
            selectedLength: selected.utf16.count,
            textBeforeSelection: before,
            selectedText: selected,
            textAfterSelection: after
        )
    }

    private func clamp(range: CFRange, toUTF16Length length: Int) -> CFRange {
        let location = min(max(range.location, 0), length)
        let maxLength = max(0, length - location)
        let clampedLength = min(max(range.length, 0), maxLength)
        return CFRange(location: location, length: clampedLength)
    }

    private func split(fullText: String, around range: CFRange) -> (before: String, selected: String, after: String) {
        let text = fullText as NSString
        let nsRange = NSRange(location: range.location, length: range.length)
        let before = text.substring(to: nsRange.location)
        let selected = text.substring(with: nsRange)
        let after = text.substring(from: nsRange.location + nsRange.length)
        return (before, selected, after)
    }
}

#!/usr/bin/env python3
"""Quick prompt-evaluation harness for FriSpeak intelligence models.

Usage:
  python3 scripts/optimize_intelligence_prompt.py \
    --prompt-file prompt.txt

Optional:
  --cases-file scripts/intelligence_prompt_cases.json
  --provider apple
  --model inception/mercury-2
  --base-system "Transform dictated speech into clean plain text."
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
import textwrap
import urllib.error
import urllib.request


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prompt-file", required=True, help="Text file containing the candidate prompt.")
    parser.add_argument(
        "--cases-file",
        default="scripts/intelligence_prompt_cases.json",
        help="JSON file with evaluation cases.",
    )
    parser.add_argument(
        "--model",
        default="inception/mercury-2",
        help="OpenRouter model ID to evaluate.",
    )
    parser.add_argument(
        "--provider",
        choices=("openrouter", "apple"),
        default="openrouter",
        help="Inference provider to evaluate.",
    )
    parser.add_argument(
        "--base-system",
        default=(
            "Transform dictated speech into clean plain text.\n"
            "Follow any extra user instructions exactly.\n"
            "Never repeat, quote, paraphrase, or mention the user instructions themselves in the output.\n"
            "Output ONLY the transformed text."
        ),
        help="System prompt used for evaluation.",
    )
    return parser.parse_args()


def load_text(path: str) -> str:
    with open(path, "r", encoding="utf-8") as handle:
        return handle.read().strip()


def load_cases(path: str) -> list[dict]:
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def call_openrouter(api_key: str, model: str, system_prompt: str, user_input: str) -> str:
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_input},
        ],
        "temperature": 0,
    }
    request = urllib.request.Request(
        "https://openrouter.ai/api/v1/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "X-Title": "FriSpeak Prompt Harness",
        },
        method="POST",
    )

    with urllib.request.urlopen(request, timeout=60) as response:
        body = json.loads(response.read().decode("utf-8"))

    return body["choices"][0]["message"]["content"].strip()


def call_apple(system_prompt: str, user_input: str) -> str:
    helper_template_path = os.path.join(os.path.dirname(__file__), "run_apple_intelligence_prompt.swift.txt")
    with open(helper_template_path, "r", encoding="utf-8") as handle:
        helper_source = handle.read()

    with tempfile.NamedTemporaryFile("w", suffix=".swift", encoding="utf-8", delete=False) as handle:
        handle.write(helper_source)
        helper_path = handle.name

    try:
        command = [
            "xcrun",
            "swift",
            helper_path,
            "--system-prompt",
            system_prompt,
            "--user-input",
            user_input,
        ]
        result = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            timeout=120,
        )
    finally:
        try:
            os.unlink(helper_path)
        except OSError:
            pass

    if result.returncode != 0:
        message = result.stderr.strip() or result.stdout.strip() or "Apple Intelligence harness failed."
        raise RuntimeError(message)

    return result.stdout.strip()


def postprocess_insertion_output(output: str, case: dict) -> str:
    helper_template_path = os.path.join(os.path.dirname(__file__), "run_local_insertion_postprocess.swift.txt")
    focused_text_context_path = os.path.join(os.path.dirname(__file__), "..", "FocusedTextContextService.swift")
    with open(focused_text_context_path, "r", encoding="utf-8") as handle:
        focused_text_context_source = handle.read()
    with open(helper_template_path, "r", encoding="utf-8") as handle:
        helper_source = handle.read()

    with tempfile.NamedTemporaryFile("w", suffix=".swift", encoding="utf-8", delete=False) as handle:
        handle.write(focused_text_context_source)
        handle.write("\n\n")
        handle.write(helper_source)
        helper_path = handle.name

    try:
        command = [
            "xcrun",
            "swift",
            helper_path,
            "--adapted-text",
            output,
            "--original-candidate-text",
            case["candidate_text"],
            "--before",
            case.get("before", ""),
            "--selected",
            case.get("selected", ""),
            "--after",
            case.get("after", ""),
        ]
        result = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            timeout=120,
        )
    finally:
        try:
            os.unlink(helper_path)
        except OSError:
            pass

    if result.returncode != 0:
        message = result.stderr.strip() or result.stdout.strip() or "Insertion postprocess harness failed."
        raise RuntimeError(message)

    return result.stdout


def build_user_prompt(candidate_prompt: str, dictated_text: str) -> str:
    parts: list[str] = [
        textwrap.dedent(
            """\
            Transform the dictated text using the control instructions below.
            The control instructions are not part of the answer.
            Never repeat, quote, paraphrase, or mention the control instructions in the output.
            Return only the final transformed text.
            """
        ).strip()
    ]

    if candidate_prompt.strip():
        parts.append(
            textwrap.dedent(
                f"""\
                <control_instructions>
                {candidate_prompt.strip()}
                </control_instructions>
                """
            ).strip()
        )

    parts.append(
        textwrap.dedent(
            f"""\
            <dictated_text>
            {dictated_text}
            </dictated_text>
            """
        ).strip()
    )

    return "\n\n".join(parts)


def xml_escape(text: str) -> str:
    return (
        text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )


def indentation_prefix(text: str) -> str:
    prefix = []
    for character in text:
        if character in (" ", "\t"):
            prefix.append(character)
        else:
            break
    return "".join(prefix)


def current_line_prefix_before_caret(before_text: str) -> str:
    return before_text.split("\n")[-1] if before_text else ""


def current_line_prefix_after_caret(after_text: str) -> str:
    return after_text.split("\n")[0] if after_text else ""


def last_non_whitespace_character(text: str) -> str | None:
    for character in reversed(text):
        if not character.isspace():
            return character
    return None


def first_non_whitespace_character(text: str) -> str | None:
    for character in text:
        if not character.isspace():
            return character
    return None


def boundary_character_description(character: str | None) -> str:
    if character is None:
        return "none"
    if character == "\n":
        return "newline"
    if character == "\t":
        return "tab"
    if character == " ":
        return "space"
    return character


def before_may_need_terminal_punctuation(before_text: str) -> bool:
    trimmed = before_text.strip()
    if not trimmed:
        return False
    last_character = trimmed[-1]
    if not last_character.isalpha():
        return False
    last_line = trimmed.split("\n")[-1]
    words = last_line.split()
    return len(words) >= 6


def build_insertion_context(case: dict) -> str:
    before = case.get("before", "")
    selected = case.get("selected", "")
    after = case.get("after", "")
    has_selection = bool(selected)

    return textwrap.dedent(
        f"""\
        <insertion_context>
        <mode>{"replace_selection" if has_selection else "insert_at_caret"}</mode>
        <boundary_facts>
        <caret_is_at_line_start>{"yes" if not before or before.endswith("\n") else "no"}</caret_is_at_line_start>
        <caret_is_after_blank_line>{"yes" if before.endswith("\n\n") else "no"}</caret_is_after_blank_line>
        <selection_spans_multiple_lines>{"yes" if "\n" in selected else "no"}</selection_spans_multiple_lines>
        <before_last_character>{xml_escape(boundary_character_description(before[-1] if before else None))}</before_last_character>
        <before_last_non_whitespace_character>{xml_escape(boundary_character_description(last_non_whitespace_character(before)))}</before_last_non_whitespace_character>
        <after_first_character>{xml_escape(boundary_character_description(after[0] if after else None))}</after_first_character>
        <after_first_non_whitespace_character>{xml_escape(boundary_character_description(first_non_whitespace_character(after)))}</after_first_non_whitespace_character>
        <before_may_need_terminal_punctuation>{"yes" if before_may_need_terminal_punctuation(before) else "no"}</before_may_need_terminal_punctuation>
        <before_context_hidden>no</before_context_hidden>
        <after_context_hidden>no</after_context_hidden>
        <before_line_indent>{xml_escape(indentation_prefix(current_line_prefix_before_caret(before)))}</before_line_indent>
        <after_line_indent>{xml_escape(indentation_prefix(current_line_prefix_after_caret(after)))}</after_line_indent>
        </boundary_facts>
        <before_excerpt>{xml_escape(before)}</before_excerpt>
        <selected_excerpt>{xml_escape(selected)}</selected_excerpt>
        <after_excerpt>{xml_escape(after)}</after_excerpt>
        </insertion_context>
        """
    ).strip()


def build_insertion_prompt(candidate_prompt: str, case: dict) -> str:
    parts = [
        textwrap.dedent(
            """\
            Adapt the candidate text so it can be inserted directly into the editor context.
            Return only the replacement text.
            Preserve any earlier user-requested transformation instructions while fitting the text at the caret.
            Do not undo, weaken, or reinterpret those instructions during this insertion-fitting step.
            Edit only the candidate text. Never return the full sentence or copy the surrounding context.
            The replacement string may include leading or trailing spaces when needed to join naturally with the surrounding text.
            If the caret sits between two words, return the candidate text with the needed spaces around it.
            If the candidate text already starts with punctuation, keep that leading punctuation.
            If the candidate starts a new sentence after terminal punctuation, capitalize its first word if needed.
            If the candidate is clearly inserted mid-sentence, lowercase its first word if needed unless it is a proper noun or intentionally capitalized.
            If mode is replace_selection and the candidate already reads naturally in place, return the full candidate unchanged.
            Never invent words that are not in the candidate text.
            Do not add leading punctuation, sentence breaks, or prefix symbols unless they are already present in the candidate text.
            Never repeat, quote, paraphrase, or mention the control instructions themselves in the output.
            """
        ).strip()
    ]

    if candidate_prompt.strip():
        parts.append(
            textwrap.dedent(
                f"""\
                <control_instructions>
                {candidate_prompt.strip()}
                </control_instructions>
                """
            ).strip()
        )

    parts.append(build_insertion_context(case))
    parts.append(f"<candidate_text>{xml_escape(case['candidate_text'])}</candidate_text>")
    parts.append(
        textwrap.dedent(
            """\
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

            before: "He said, \""
            candidate: "hello"
            after: "\""
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

            before: "He wrote, \""
            candidate: "hello there"
            after: "\" yesterday."
            output: "hello there"
            """
        ).strip()
    )

    return "\n\n".join(parts)


def system_prompt_for_case(case: dict, base_system: str) -> str:
    mode = case.get("mode", "transform")
    built_in = case.get("use_built_in_prompting", True)

    if mode == "insertion":
        if not built_in:
            return textwrap.dedent(
                """\
                You rewrite text so it fits naturally into an existing document at the current caret location.
                Return only the exact replacement string that should be inserted.
                Preserve the candidate text's meaning.
                Edit only the candidate text. Never return the full sentence or surrounding context.
                Output only plain text.
                """
            ).strip()
        return textwrap.dedent(
            """\
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
        ).strip()

    if built_in:
        return textwrap.dedent(
            """\
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
        ).strip()

    return base_system.strip()


def user_input_for_case(candidate_prompt: str, case: dict) -> str:
    mode = case.get("mode", "transform")
    if mode == "insertion":
        return build_insertion_prompt(candidate_prompt, case)
    return build_user_prompt(candidate_prompt, case["input"])


def evaluate_case(output: str, case: dict) -> tuple[bool, list[str]]:
    failures: list[str] = []

    expected_equals = case.get("expected_equals")
    if expected_equals is not None and output != expected_equals:
        failures.append(f"expected exact match: {expected_equals!r}")

    for needle in case.get("expected_contains", []):
        if needle not in output:
            failures.append(f"missing substring: {needle!r}")

    for needle in case.get("expected_not_contains", []):
        if needle in output:
            failures.append(f"unexpected substring present: {needle!r}")

    expected_one_of = case.get("expected_one_of")
    if expected_one_of is not None and output not in expected_one_of:
        failures.append(f"expected one of: {expected_one_of!r}")

    return (not failures, failures)


def main() -> int:
    args = parse_args()
    api_key = os.environ.get("OPENROUTER_API_KEY", "").strip()
    if args.provider == "openrouter" and not api_key:
        print("OPENROUTER_API_KEY is required for --provider openrouter.", file=sys.stderr)
        return 2

    candidate_prompt = load_text(args.prompt_file)
    cases = load_cases(args.cases_file)
    passed = 0
    total = len(cases)

    for index, case in enumerate(cases, start=1):
        case_mode = case.get("mode", "transform")
        print(f"[{index}/{total}] {case['name']} [{case_mode}]")
        system_prompt = system_prompt_for_case(case, args.base_system)
        user_input = user_input_for_case(candidate_prompt, case)
        try:
            if args.provider == "apple":
                output = call_apple(system_prompt, user_input)
            else:
                output = call_openrouter(api_key, args.model, system_prompt, user_input)
            if case_mode == "insertion":
                output = postprocess_insertion_output(output, case)
        except urllib.error.HTTPError as error:
            body = error.read().decode("utf-8", errors="replace")
            print(f"  HTTP {error.code}: {body}")
            continue
        except Exception as error:  # noqa: BLE001
            print(f"  Request failed: {error}")
            continue

        ok, failures = evaluate_case(output, case)
        status = "PASS" if ok else "FAIL"
        print(f"  {status}: {output}")
        if failures:
            for failure in failures:
                print(f"    - {failure}")
        if ok:
            passed += 1

    print(f"\nSummary: {passed}/{total} passed")
    return 0 if passed == total else 1


if __name__ == "__main__":
    raise SystemExit(main())

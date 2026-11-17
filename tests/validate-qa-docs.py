#!/usr/bin/env python3
"""Validate the Bloom QA handoff package's files, test cases, and tracker."""

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1] / "docs" / "qa"
EXPECTED_DOCS = {
    f"{number:02d}-{name}.md"
    for number, name in enumerate(
        [
            "ARCHITECTURE-INVENTORY",
            "OPEN-SOURCE-RESEARCH",
            "FEATURE-COMPLETENESS-AUDIT",
            "GAP-AND-RISK-REGISTER",
            "IMPLEMENTATION-AND-VERIFICATION-PLAN",
            "AUTOMATED-TEST-MATRIX",
            "COMPUTER-USE-MASTER-PLAYBOOK",
            "COMPUTER-USE-TEST-CASES",
            "TEST-DATA-AND-ENVIRONMENT",
            "FAILURE-RECOVERY-RUNBOOK",
            "TEST-EXECUTION-TRACKER",
            "FINAL-READINESS-ASSESSMENT",
            "SMALL-MODEL-EXECUTION-PROMPT",
        ],
        start=1,
    )
}
REQUIRED_FIELDS = (
    "Test ID",
    "Feature",
    "Objective",
    "Priority",
    "Risk",
    "Prerequisites",
    "Environment",
    "Test data",
    "Initial state",
    "Preparation steps",
    "Execution steps",
    "Evidence to capture",
    "Pass criteria",
    "Fail criteria",
    "Recovery procedure",
    "Cleanup procedure",
    "Related code",
    "Related automated tests",
    "Dependencies",
    "Retry policy",
    "Escalation rule",
)


def main() -> int:
    errors: list[str] = []
    actual_docs = {path.name for path in ROOT.glob("*.md")}
    if actual_docs != EXPECTED_DOCS:
        errors.append(
            "QA document set differs; missing: "
            f"{sorted(EXPECTED_DOCS - actual_docs)}; extra: "
            f"{sorted(actual_docs - EXPECTED_DOCS)}"
        )

    cases_path = ROOT / "08-COMPUTER-USE-TEST-CASES.md"
    tracker_path = ROOT / "11-TEST-EXECUTION-TRACKER.md"
    cases_text = cases_path.read_text(encoding="utf-8")
    tracker_text = tracker_path.read_text(encoding="utf-8")
    case_blocks = re.split(r"(?=\*\*Test ID:\*\*)", cases_text)
    case_ids: list[str] = []

    for block in case_blocks:
        match = re.search(r"\*\*Test ID:\*\*\s*([A-Z0-9-]+)", block)
        if not match:
            continue
        case_id = match.group(1)
        case_ids.append(case_id)

        for field in REQUIRED_FIELDS:
            if not re.search(r"\*\*" + re.escape(field) + r":\*\*", block):
                errors.append(f"{case_id}: missing required field {field}")

        execution = re.search(
            r"\*\*Execution steps:\*\*(.*?)(?=\n- \*\*Evidence to capture:)",
            block,
            re.DOTALL,
        )
        if execution is None:
            errors.append(f"{case_id}: missing execution steps")
            continue

        steps = len(re.findall(r"(?:^|\s)\d+\.\s", execution.group(1)))
        outcomes = len(re.findall(r"\*\*expected:\*\*", execution.group(1), re.IGNORECASE))
        if steps == 0 or steps != outcomes:
            errors.append(
                f"{case_id}: {steps} numbered steps but {outcomes} inline expected outcomes"
            )

        if not re.search(r"^\| " + re.escape(case_id) + r" \|", tracker_text, re.MULTILINE):
            errors.append(f"{case_id}: missing tracker row")

    if not case_ids:
        errors.append("No structured test cases found")
    if len(case_ids) != len(set(case_ids)):
        errors.append("Duplicate test IDs found")

    for path in ROOT.glob("*.md"):
        for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            if line.rstrip() != line:
                errors.append(f"{path.name}:{line_number}: trailing whitespace")

    if errors:
        print("QA documentation validation failed:")
        print("\n".join(f"- {error}" for error in errors))
        return 1

    print(f"PASS: {len(actual_docs)} QA documents, {len(case_ids)} unique cases, required fields, expected outcomes, tracker rows, and whitespace")
    return 0


if __name__ == "__main__":
    sys.exit(main())

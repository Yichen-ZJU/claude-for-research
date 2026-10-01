#!/usr/bin/env python3
"""Deterministic checks for a structured rebuttal case workspace.

The script deliberately does not fetch venues, run experiments, or generate prose.
It only creates templates, counts text, and blocks unsafe workflow transitions.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


BASE_ARTIFACT_TEMPLATES = {
    "RULES_SNAPSHOT.md": "# Rules Snapshot\n\nRecord the official venue rules, URL, fetch date, and relevant excerpts.\n",
    "ISSUE_BOARD.md": "# Issue Board\n\nRecord one atomic issue per row and link it to evidence and commitments.\n",
    "REVIEWER_LANES.md": "# Reviewer Lanes\n\nRecord exactly one current lane per reviewer and preserve issue-level stance separately.\n",
    "EVIDENCE_LEDGER.md": "# Evidence Ledger\n\nRecord the source and confirmation status of every factual claim.\n",
    "STRATEGY.md": "# Strategy\n\nState the structured expert outlook, priorities, risks, and approval status.\n",
    "DRAFT.md": "# Draft\n\nKeep reviewer-facing text here until facts and commitments are confirmed.\n",
    "PASTE_READY.md": "",
    "PASTE_READY.txt": "",
    "REVISION_PLAN.md": "# Revision Plan\n\nMap every paper-edit promise to an issue ID and commitment status.\n",
    "FOLLOWUP_LOG.md": "# Follow-up Log\n\nAppend new comments, delta replies, and approval records.\n",
    "AC_SUMMARY.md": "# AC Summary\n\nSummarize the paper contribution, review record, author response, unresolved points, and requested handling.\n",
    "AC_MESSAGE.md": "# AC Message\n\nKeep chair-facing text separate from the scientific response and issue report.\n",
    "CASE_INTAKE.md": "# Case Intake\n\n- Paper PDF: [path or attachment]\n- Venue/cycle: [optional at first turn]\n- Stage/deadline: [optional]\n- Existing raw response: none | attached | pasted\n- Confirmed new evidence: none | listed in EVIDENCE_LEDGER.md\n- Mentor constraints: [optional]\n",
    "REVIEWS_INPUT.md": "# Reviews Input\n\nCopy complete raw OpenReview text here. Preserve reviewer IDs, scores, confidence, timestamps, visibility, author responses, and follow-ups.\n\n## Reviewer R1\n\n### Metadata\n\n- Score: [copy exactly]\n- Confidence: [copy exactly]\n- Timestamp: [if available]\n\n### Raw review\n\n[paste complete review text]\n",
}

ARR_ARTIFACT_TEMPLATES = {
    "ARR_THREAD_PLAN.md": "# ARR Thread Plan\n\nTrack response number, timestamp, new information, issues addressed, and stop condition per reviewer thread.\n",
    "ARR_ISSUE_REPORT.md": "# ARR Issue Report\n\nKeep any official ARR review-issue report separate from the scientific response.\n",
}

NEURIPS_ARTIFACT_TEMPLATES = {
    "NEURIPS_META_REVIEW_MAP.md": "# NeurIPS Initial Meta-Review Map\n\nMap each critical initial-meta-review concern to reviewer issues, evidence, response files, and completion status.\n",
    "NEURIPS_THREAD_PLAN.md": "# NeurIPS Thread Plan\n\nTrack initial responses, new questions, delta replies, visibility phase, late-review watch, and stop conditions per reviewer.\n",
    "NEURIPS_AC_CONFIDENTIAL_MESSAGE.md": "# NeurIPS Author AC Confidential Comment\n\nUse only for a narrow factual or procedural request to the AC. Record readers, anchors, requested handling, and mentor approval.\n",
    "NEURIPS_CODE_LINK_OFFICIAL_COMMENT.md": "# NeurIPS AC-only Official Comment\n\nUse only for the reviewer-requested anonymized code-link exception after rule, readers, anonymity, and mentor checks.\n",
}

NEURIPS_PROFILES = {
    "neurips-2026-main": {"cycle": "2026", "track": "main"},
    "neurips-2026-ed": {"cycle": "2026", "track": "evaluations_and_datasets"},
}

NEURIPS_MAIN_CONTRIBUTION_TYPES = {
    "general",
    "theory",
    "use_inspired",
    "concept_and_feasibility",
    "negative_results",
}
NEURIPS_ED_CONTRIBUTION_TYPES = {
    "benchmark_design_and_analysis",
    "evaluation_methodology_and_metrics",
    "evaluation_tools_frameworks_and_infrastructure",
    "reproducibility_auditing_and_stress_testing",
    "human_centered_and_interaction_based_evaluation",
    "datasets_and_data_resources",
    "dataset_documentation_auditing_and_responsible_data",
    "data_centric_methods_and_empirical_analyses",
}


DEFAULT_STATE: dict[str, Any] = {
    "schema_version": "1.0",
    "case_id": "",
    "stage": "intake",
    "intake_mode": "unknown",
    "paper_status": "missing",
    "raw_review_status": "unknown",
    "author_response_status": "unknown",
    "venue": {
        "name": "",
        "cycle": "",
        "track": "",
        "rules_url": "",
        "rules_fetched_at": "",
        "profile": "",
        "rules_profile_id": "",
        "rules_revision": "",
        "rules_status": "unknown",
        "response_mode": "",
        "limit_scope": "",
        "limit_status": "unknown",
        "limit_source": "",
        "limit_unit": "",
        "limit_value": None,
        "links_allowed": False,
        "files_allowed": False,
        "paper_revision_allowed": False,
        "new_results_policy": "unknown",
        "arr": {"thread_response_counts": {}},
        "neurips": {
            "phase": "unknown",
            "initial_meta_review_status": "unknown",
            "contribution_type": "",
            "response_files": {},
            "response_channel": "",
            "review_count": 0,
            "additional_review_expected": False,
            "proceed_without_meta_review_approved": False,
            "timeline": {
                "initial_response_start": "",
                "initial_response_end": "",
                "author_reviewer_ac_start": "",
                "author_action_deadline": "",
                "reviewer_ac_only_start": "",
                "reviewer_ac_discussion_end": "",
                "email_summary_end": "",
                "timeline_conflict_status": "unknown",
                "author_action_deadline_verified": False,
                "current_openreview_form_verified_at": "",
            },
        },
    },
    "deadlines": {},
    "reviewers": [],
    "issues": [],
    "evidence": [],
    "commitments": [],
    "approvals": {
        "strategy": "pending",
        "facts": "pending",
        "paste_ready": "pending",
        "escalation": "not_requested",
    },
}

LANES = {
    "positive-champion",
    "positive-conditional",
    "mixed-swing",
    "negative-addressable",
    "negative-fundamental",
    "negative-procedural-risk",
    "unknown-insufficient",
}
SCALE_DIMENSIONS = {"high", "medium", "low", "unknown"}
ADDRESSABILITY = {"existing_evidence", "small_add_on", "paper_revision", "unsupported_now", "unknown"}


def _write_json(path: Path, value: Any) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def initialize_case(
    case_dir: Path, profile: str = "", track: str = "", cycle: str = ""
) -> None:
    """Create a case workspace without overwriting existing files."""

    case_dir = Path(case_dir)
    case_dir.mkdir(parents=True, exist_ok=True)
    state_path = case_dir / "CASE_STATE.json"
    if not state_path.exists():
        state = json.loads(json.dumps(DEFAULT_STATE))
        if profile:
            state["venue"].update({"profile": profile, "track": track, "cycle": cycle})
        _write_json(state_path, state)
    templates = dict(BASE_ARTIFACT_TEMPLATES)
    # Preserve the legacy default workspace for existing ARR users. New NeurIPS
    # workspaces receive only the artifacts applicable to their profile.
    if profile in {"", "arr"}:
        templates.update(ARR_ARTIFACT_TEMPLATES)
    if profile == "neurips":
        templates.update(NEURIPS_ARTIFACT_TEMPLATES)
    for filename, content in templates.items():
        path = case_dir / filename
        if not path.exists():
            path.write_text(content, encoding="utf-8")
    if profile == "neurips":
        (case_dir / "NEURIPS_RESPONSES").mkdir(exist_ok=True)


def count_text(path: Path, unit: str) -> int:
    text = Path(path).read_text(encoding="utf-8")
    if unit == "chars":
        return len(text)
    if unit == "words":
        return len(re.findall(r"\S+", text))
    raise ValueError(f"unsupported unit: {unit}")


def _load_state(case_dir: Path) -> tuple[dict[str, Any] | None, list[str]]:
    path = Path(case_dir) / "CASE_STATE.json"
    if not path.exists():
        return None, ["CASE_STATE.json is missing"]
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return None, [f"CASE_STATE.json is invalid JSON: {exc}"]
    if not isinstance(value, dict):
        return None, ["CASE_STATE.json must contain an object"]
    return value, []


def _venue_rules_errors(state: dict[str, Any]) -> list[str]:
    venue = state.get("venue") or {}
    errors: list[str] = []
    if not venue.get("rules_url") or not venue.get("rules_fetched_at"):
        errors.append("official rules snapshot is missing")
    return errors


def _intake_errors(state: dict[str, Any]) -> list[str]:
    mode = state.get("intake_mode")
    errors: list[str] = []
    if state.get("paper_status") != "provided":
        errors.append("paper PDF is not marked as provided")
    if mode not in {"paste", "local_markdown"}:
        if mode == "url_reference_only":
            errors.append("URL-only intake is triage-only; provide pasted or local raw review text")
        else:
            errors.append("intake_mode must be paste or local_markdown")
    if state.get("raw_review_status") != "confirmed":
        errors.append("raw review text must be marked confirmed")
    return errors


def _arr_profile_errors(state: dict[str, Any]) -> list[str]:
    venue = state.get("venue") or {}
    if venue.get("profile") != "arr":
        return []
    errors: list[str] = []
    if venue.get("response_mode") != "text_only":
        errors.append("ARR response mode must be text_only")
    if venue.get("links_allowed") is not False:
        errors.append("ARR responses must disallow external links")
    if venue.get("new_results_policy") != "direct_minor_add_on_only":
        errors.append("ARR new-results policy must be direct_minor_add_on_only")
    limit_status = venue.get("limit_status")
    if limit_status not in {"verified_numeric", "officially_unspecified"}:
        errors.append("ARR limit status must be verified_numeric or officially_unspecified")
    if limit_status == "verified_numeric" and (
        venue.get("limit_unit") not in {"chars", "words"}
        or not isinstance(venue.get("limit_value"), int)
        or venue.get("limit_value") <= 0
    ):
        errors.append("ARR verified numeric limit requires a positive limit_unit and limit_value")
    return errors


def _arr_evidence_errors(state: dict[str, Any]) -> list[str]:
    if (state.get("venue") or {}).get("profile") != "arr":
        return []
    errors: list[str] = []
    allowed = {"paper", "direct_minor_add_on", "author_confirmed_clarification"}
    blocked = {"unsolicited_new", "major_post_submission"}
    for evidence in state.get("evidence", []):
        if not isinstance(evidence, dict):
            continue
        evidence_id = evidence.get("id", "<unnamed evidence>")
        origin = evidence.get("origin")
        if origin in blocked:
            errors.append(f"unsolicited or substantial new results are not allowed in ARR: {evidence_id}")
        elif origin not in allowed:
            errors.append(f"ARR evidence origin is missing or invalid: {evidence_id}")
    return errors


def _neurips_profile_errors(state: dict[str, Any]) -> list[str]:
    venue = state.get("venue") or {}
    if venue.get("profile") != "neurips":
        return []
    if venue.get("rules_status") == "future_unpublished":
        return ["NeurIPS future rules are unpublished; triage only"]

    errors: list[str] = []
    profile_id = venue.get("rules_profile_id")
    profile = NEURIPS_PROFILES.get(profile_id)
    if not profile:
        errors.append("NeurIPS rules_profile_id is missing or unsupported")
        return errors
    if venue.get("cycle") != profile["cycle"] or venue.get("track") != profile["track"]:
        errors.append("NeurIPS rules_profile_id does not match the case cycle and track")
    if venue.get("rules_revision") != "neurips-2026-pc-email-july":
        errors.append("NeurIPS rules_revision must be 'neurips-2026-pc-email-july'")
    required = {
        "rules_status": "current_official",
        "response_mode": "per_review_openreview",
        "limit_scope": "per_review",
        "limit_unit": "chars",
        "limit_value": 10000,
        "links_allowed": False,
        "files_allowed": False,
        "paper_revision_allowed": False,
        "new_results_policy": "direct_response_allowed_submission_remains_basis",
    }
    for key, expected in required.items():
        if venue.get(key) != expected:
            errors.append(f"NeurIPS {key} must be {expected!r}")
    neurips = venue.get("neurips") or {}
    if neurips.get("phase") not in {
        "initial_response",
        "author_reviewer_ac_discussion",
        "reviewer_ac_only",
        "post_decision",
    }:
        errors.append("NeurIPS phase is missing or invalid")
    if neurips.get("initial_meta_review_status") not in {
        "provided", "pending_expected", "not_provided_by_venue"
    }:
        errors.append("NeurIPS initial meta-review must be provided, pending, or explicitly unavailable")
    contribution_type = neurips.get("contribution_type")
    allowed_types = (
        NEURIPS_ED_CONTRIBUTION_TYPES
        if venue.get("track") == "evaluations_and_datasets"
        else NEURIPS_MAIN_CONTRIBUTION_TYPES
    )
    if contribution_type not in allowed_types:
        errors.append("NeurIPS contribution_type is missing or invalid for the selected track")
    if neurips.get("response_channel") != "per_review_rebuttal":
        errors.append("NeurIPS response_channel must be per_review_rebuttal")
    reviewers = state.get("reviewers") or []
    if neurips.get("review_count") != len(reviewers):
        errors.append("NeurIPS review_count must equal the number of tracked reviews")
    if len(reviewers) == 2 and neurips.get("additional_review_expected") is not True:
        errors.append("NeurIPS cases with two reviews must track an expected additional review")
    timeline = neurips.get("timeline") or {}
    expected_timeline = {
        "initial_response_start": "2026-07-23",
        "initial_response_end": "2026-07-27",
        "author_reviewer_ac_start": "2026-07-27",
        "author_action_deadline": "2026-08-03",
        "reviewer_ac_only_start": "2026-08-03",
        "reviewer_ac_discussion_end": "2026-08-10",
        "email_summary_end": "2026-08-07",
        "timeline_conflict_status": "email_summary_conflict_recorded",
    }
    for key, expected in expected_timeline.items():
        if timeline.get(key) != expected:
            errors.append(f"NeurIPS timeline {key} must be {expected!r}")
    return errors


def _neurips_evidence_errors(state: dict[str, Any]) -> list[str]:
    if (state.get("venue") or {}).get("profile") != "neurips":
        return []
    errors: list[str] = []
    allowed = {"paper", "direct_response_new_result", "author_confirmed_clarification"}
    blocked = {"unconfirmed_new_result", "major_scope_change", "unsolicited_new"}
    for evidence in state.get("evidence", []):
        if not isinstance(evidence, dict):
            continue
        evidence_id = evidence.get("id", "<unnamed evidence>")
        origin = evidence.get("origin")
        if origin in blocked:
            errors.append(f"unconfirmed or scope-expanding NeurIPS evidence is not allowed: {evidence_id}")
        elif origin not in allowed:
            errors.append(f"NeurIPS evidence origin is missing or invalid: {evidence_id}")
    return errors


def _issue_errors(state: dict[str, Any]) -> list[str]:
    reviewers = state.get("reviewers") or []
    issues = state.get("issues") or []
    errors: list[str] = []
    if not reviewers:
        errors.append("reviewer records are missing")
    if not issues:
        errors.append("no atomic reviewer issues are tracked")
    reviewer_ids = {r.get("id") for r in reviewers if isinstance(r, dict)}
    for reviewer in reviewers:
        if not isinstance(reviewer, dict):
            errors.append("a reviewer record is not an object")
            continue
        reviewer_id = reviewer.get("id", "<unnamed reviewer>")
        if reviewer.get("lane") not in LANES:
            errors.append(f"{reviewer_id} has no valid reviewer lane")
        for dimension in ("support", "persuadability", "decision_relevance"):
            if reviewer.get(dimension) not in SCALE_DIMENSIONS:
                errors.append(f"{reviewer_id} has no valid {dimension} dimension")
        if reviewer.get("addressability") not in ADDRESSABILITY:
            errors.append(f"{reviewer_id} has no valid addressability dimension")
    for issue in issues:
        if not isinstance(issue, dict):
            errors.append("an issue record is not an object")
            continue
        issue_id = issue.get("id", "<unnamed issue>")
        if issue.get("reviewer_id") not in reviewer_ids:
            errors.append(f"{issue_id} references an unknown reviewer")
        if not issue.get("status"):
            errors.append(f"{issue_id} has no status")
        if issue.get("stance_signal") not in {"positive", "mixed", "negative", "unknown"}:
            errors.append(f"{issue_id} has no valid stance_signal")
    return errors


def _text_errors(
    path: Path, venue: dict[str, Any], label: str, enforce_limit: bool = True
) -> list[str]:
    if not path.exists() or not path.read_text(encoding="utf-8").strip():
        return [f"{label} is missing or empty"]
    text = path.read_text(encoding="utf-8")
    errors: list[str] = []
    if not venue.get("links_allowed", False) and re.search(r"https?://|www\.", text, re.I):
        errors.append("external links are not allowed")
    if "—" in text or "---" in text:
        errors.append("em dash or triple-hyphen punctuation is not allowed in English draft text")
    if re.search(r"\b(?:TODO|TBD|FIXME|<[^>]+>)\b", text, re.I):
        errors.append("unresolved placeholder text is not allowed")
    limit = venue.get("limit_value")
    unit = venue.get("limit_unit")
    if enforce_limit and isinstance(limit, int) and unit in {"chars", "words"}:
        if count_text(path, unit) > limit:
            errors.append(f"{label} exceeds the {unit} limit")
    return errors


def _neurips_response_errors(case_dir: Path, state: dict[str, Any]) -> list[str]:
    venue = state.get("venue") or {}
    if venue.get("profile") != "neurips":
        return []
    errors: list[str] = []
    neurips = venue.get("neurips") or {}
    timeline = neurips.get("timeline") or {}
    if not timeline.get("author_action_deadline_verified") or not timeline.get("current_openreview_form_verified_at"):
        errors.append("NeurIPS author-action deadline must be verified in the live OpenReview form before paste-ready output")
    if (
        neurips.get("initial_meta_review_status") == "pending_expected"
        and neurips.get("proceed_without_meta_review_approved") is not True
    ):
        errors.append("pending initial meta-review requires mentor-approved proceed_without_meta_review_approved before paste-ready output")
    if neurips.get("phase") in {"reviewer_ac_only", "post_decision"}:
        errors.append("NeurIPS authors cannot post responses in the current phase")
    response_files = neurips.get("response_files") or {}
    reviewer_ids = {
        reviewer.get("id") for reviewer in state.get("reviewers", []) if isinstance(reviewer, dict)
    }
    for reviewer_id in reviewer_ids:
        relative_path = response_files.get(reviewer_id)
        if not relative_path:
            errors.append(f"NeurIPS response file is missing for {reviewer_id}")
            continue
        path = Path(case_dir) / relative_path
        if path.parent != Path(case_dir) / "NEURIPS_RESPONSES":
            errors.append(f"NeurIPS response file for {reviewer_id} must be under NEURIPS_RESPONSES")
            continue
        errors.extend(_text_errors(path, venue, f"NeurIPS response for {reviewer_id}"))
    manifest = Path(case_dir) / "PASTE_READY.md"
    if not manifest.exists() or not manifest.read_text(encoding="utf-8").strip():
        errors.append("PASTE_READY.md manifest is missing or empty")
    else:
        manifest_text = manifest.read_text(encoding="utf-8")
        for reviewer_id in reviewer_ids:
            if reviewer_id not in manifest_text:
                errors.append(f"PASTE_READY.md manifest does not list {reviewer_id}")
    return errors


def _draft_errors(case_dir: Path, state: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    errors.extend(_intake_errors(state))
    errors.extend(_venue_rules_errors(state))
    errors.extend(_arr_profile_errors(state))
    errors.extend(_neurips_profile_errors(state))
    errors.extend(_issue_errors(state))
    errors.extend(_arr_evidence_errors(state))
    errors.extend(_neurips_evidence_errors(state))
    if (state.get("approvals") or {}).get("strategy") != "approved":
        errors.append("strategy approval is required before drafting")
    if not (Path(case_dir) / "DRAFT.md").exists():
        errors.append("DRAFT.md is missing")

    evidence_by_id = {
        e.get("id"): e for e in state.get("evidence", []) if isinstance(e, dict)
    }
    allowed_statuses = {"paper_verified", "author_confirmed", "public_verified"}
    for issue in state.get("issues", []):
        if not isinstance(issue, dict):
            continue
        if issue.get("status") not in {"answered", "deferred", "needs_user_input"}:
            errors.append(f"{issue.get('id', '<unnamed issue>')} is not dispositioned")
        for evidence_id in issue.get("evidence_ids", []):
            evidence = evidence_by_id.get(evidence_id)
            if not evidence:
                errors.append(f"{issue.get('id', '<unnamed issue>')} references missing evidence {evidence_id}")
            elif evidence.get("status") not in allowed_statuses:
                errors.append(f"unverified evidence: {evidence_id}")

    draft_path = Path(case_dir) / "DRAFT.md"
    errors.extend(
        _text_errors(
            draft_path,
            state.get("venue") or {},
            "DRAFT.md",
            enforce_limit=(state.get("venue") or {}).get("profile") != "neurips",
        )
    )
    return errors


def validate_case(case_dir: Path, gate: str) -> list[str]:
    """Return blocking errors for a workflow gate; an empty list means pass."""

    state, errors = _load_state(Path(case_dir))
    if state is None:
        return errors
    if gate not in {"strategy", "draft", "paste-ready", "escalation"}:
        return [f"unknown gate: {gate}"]
    if gate == "strategy":
        errors.extend(_intake_errors(state))
        errors.extend(_venue_rules_errors(state))
        errors.extend(_arr_profile_errors(state))
        errors.extend(_neurips_profile_errors(state))
        errors.extend(_issue_errors(state))
        return errors
    errors.extend(_draft_errors(Path(case_dir), state))
    if gate == "draft":
        return errors
    approvals = state.get("approvals") or {}
    if gate == "paste-ready":
        if approvals.get("facts") != "approved":
            errors.append("fact approval is required before paste-ready output")
        if approvals.get("paste_ready") != "approved":
            errors.append("paste-ready approval is required")
        if (state.get("venue") or {}).get("profile") == "neurips":
            errors.extend(_neurips_response_errors(Path(case_dir), state))
        else:
            errors.extend(_text_errors(Path(case_dir) / "PASTE_READY.md", state.get("venue") or {}, "PASTE_READY.md"))
        return errors
    if approvals.get("escalation") not in {"mentor_approved", "approved"}:
        errors.append("mentor approval is required before escalation")
    return errors


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    init_parser = subparsers.add_parser("init")
    init_parser.add_argument("--case-dir", required=True, type=Path)
    init_parser.add_argument("--profile", choices=["arr", "neurips"])
    init_parser.add_argument("--track", default="")
    init_parser.add_argument("--cycle", default="")

    check_parser = subparsers.add_parser("check")
    check_parser.add_argument("--case-dir", required=True, type=Path)
    check_parser.add_argument(
        "--gate", required=True, choices=["strategy", "draft", "paste-ready", "escalation"]
    )

    count_parser = subparsers.add_parser("count")
    count_parser.add_argument("--file", required=True, type=Path)
    count_parser.add_argument("--unit", choices=["chars", "words"], default="chars")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    if args.command == "init":
        initialize_case(args.case_dir, args.profile or "", args.track, args.cycle)
        print(f"initialized case workspace: {args.case_dir}")
        return 0
    if args.command == "count":
        print(count_text(args.file, args.unit))
        return 0
    errors = validate_case(args.case_dir, args.gate)
    if errors:
        for error in errors:
            print(f"BLOCKED: {error}")
        return 1
    print(f"PASS: {args.gate}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

# HNI isolated Flutter proof of concept

Status: experimental, no production integration. Branch: `experiment/hni-native-intelligence-poc`.

## Core principle
Intelligence-native means context-aware decisions and user assistance are ordinary application capabilities rather than a separate assistant. Phase 1 uses deterministic, explainable, local matching, without LLM API calls, sensitive tracking, or changes to user-visible workflows.

## Shared contract
Inputs: opted-in, user-authorised interests or questions. Output: ranked suggestions including a human-readable reason, never automatic contact, disclosure or irreversible action.
Controls: opt in/out, dismiss, review before action, deterministic fallback. Use only scoped knowledge authorised for the viewer.

## Pilot boundaries
- Happnn: local activity-interest ranking, not proximity tracking or matching real accounts.
- IntQAFlow: local knowledge candidate ranking, not querying organisations or changing verified answers.
- TempConnect: follow-on skills / needs matching only after privacy and contact-card visibility review.

## Planned validation
Unit tests for exact matches, partial overlap, irrelevant content, empty input, and stable ranking. Future integration requires permission checks on authoritative backend, abuse protections, telemetry controls and human acceptance of UI.

## Non-goals
No production changes, no deployed endpoints, no background collection, no agent runtime and no inter-app data sharing.

---
layout: default
title: Agents
---

# Agents

## Overview

Hakumai relies on specialized agents to automate interactions with external services and streamline workflows for broadcasters and moderators. This document outlines the expected behavior, responsibilities, and operational guidelines for each agent that participates in the Hakumai ecosystem.

## Agent Roles

- **Niconico Integration Agent** — synchronizes live broadcast metadata, room status, and available comment streams.
- **Comment Processing Agent** — filters, ranks, and forwards incoming messages to the desktop client and optional speech synthesis pipelines.
- **Notification Agent** — dispatches alerts for critical events (connection issues, moderator actions, donation triggers) to the appropriate user channels.

Use these role descriptions as a baseline when designing new automation flows or refining existing ones.

## Communication Guidelines

- All interactions with user-facing agents must be conducted in Japanese to match the expectations of Hakumai broadcasters and viewers.
- Logs and telemetry generated for internal diagnostics may remain in English for consistency with the codebase.
- When integrating third-party APIs, prefer English for protocol-level messages but provide localized summaries to users.

## Operational Workflow

1. Monitor platform events for triggers relevant to the assigned role.
2. Validate incoming data, enrich it if necessary, and normalize formats before distribution.
3. Deliver responses or actions through the designated channels while adhering to the communication guidelines above.
4. Record outcomes and status updates for later auditing and troubleshooting.

## Reliability and Monitoring

- Implement retry logic with exponential backoff for recoverable failures.
- Surface actionable error messages in Japanese when user intervention is required.
- Provide structured metrics (latency, throughput, failure rates) to the central monitoring dashboard.

## Security Considerations

- Store credentials using the Hakumai secure storage facilities; never embed secrets in agent code or logs.
- Restrict agent permissions to the minimum scope needed for each task.
- Audit third-party dependencies regularly and track upstream security advisories.

## Next Steps

Expand each section with concrete implementation details, configuration examples, and escalation procedures as the agent architecture matures.

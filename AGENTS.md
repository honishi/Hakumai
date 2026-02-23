# Hakumai Agents

This document defines the operational agents that are implemented in the Hakumai macOS app today.
It is intended for contributors who add features, fix bugs, or design new automation around live
comment ingestion and moderation support.

## System Context

Hakumai is a desktop comment viewer for Niconico Live broadcasts. Agent responsibilities are split
across manager classes under `Hakumai/Managers` and orchestrated mainly by:

- `Hakumai/Controllers/MainWindowController/MainViewController.swift`
- `Hakumai/AppDelegate.swift`

The current pipeline is:

1. Authenticate and manage OAuth tokens.
2. Resolve live metadata and stream endpoints.
3. Ingest NDGR stream payloads (protobuf, chunked stream).
4. Normalize payloads into `Chat` and then `Message`.
5. Apply filtering, detection, and optional speech.
6. Update UI, local notifications, and window indicators.

## Communication Policy

- User-facing interactions must be localized for Japanese users.
- Internal logs, protocol payloads, and low-level diagnostics can remain English.
- This file is intentionally written in English for developer-facing clarity.

## Agent Catalog

### 1. Session Agent

Primary components:

- `Hakumai/Managers/AuthManager/AuthManager.swift`
- `Hakumai/Managers/NicoManager/NicoManager.swift`
- `Hakumai/Managers/AuthManager/TokenStore.swift`

Responsibilities:

- Validate token presence before live connection.
- Refresh access tokens when OAuth endpoints return invalid-token responses.
- Retrieve live info, user info, and websocket endpoint in order.
- Start and stop connection-related timers.

Failure behavior:

- If token refresh fails, stop connection setup and surface failure through delegate callbacks.
- On disconnect/reconnect conditions, hand off to reconnect flow with context and reason.

Security rules:

- Persist tokens only through keychain-backed storage (`SAMKeychain`).
- Never hardcode secrets or print raw credentials in logs.

### 2. Stream Ingestion Agent (NDGR)

Primary components:

- `Hakumai/Managers/NicoManager/NdgrClient.swift`
- `Hakumai/Managers/NicoManager/NdgrClientProtocol.swift`
- protobuf models under `Hakumai/Models/dwango/...`

Responsibilities:

- Read NDGR playlist entries and message segments from streaming HTTP endpoints.
- Parse length-delimited protobuf frames safely.
- Deduplicate messages by meta ID.
- Convert payloads into normalized `Chat` objects (comment, gift, nicoad, system-like events).
- Separate history catch-up from near-realtime messages and emit both via delegate callbacks.

Failure behavior:

- Network timeouts and lost-connection errors may retry once via `NdgrRequestRetrier`.
- Stream truncation is buffered and retried on next chunk.
- Excess unread buffer is dropped defensively when it grows too large.
- State-level disconnect signals trigger explicit disconnect.

### 3. Comment Processing Agent

Primary components:

- `Hakumai/Managers/MessageContainer/MessageContainer.swift`
- `Hakumai/Managers/CommentDetector/KusaCommentDetector.swift`
- `Hakumai/Managers/CommentDetector/StoreCommentDetector.swift`
- `Hakumai/Managers/HandleNameManager/HandleNameManager.swift`
- `Hakumai/Managers/CommentCopier/CommentCopier.swift`

Responsibilities:

- Convert `Chat` to table-ready `Message` with chat type metadata.
- Maintain both source and filtered message arrays in a thread-safe container.
- Apply mute filters (user IDs, words) and optional debug visibility.
- Detect rapid "kusa" bursts and non-arena store comments.
- Resolve and persist handle names from user comments.
- Export filtered comments with resolved user labels.

Concurrency rules:

- Keep append/count/read operations synchronized.
- Run long rebuild operations in background, then swap filtered state atomically on main thread.

### 4. Speech Agent

Primary components:

- `Hakumai/Managers/SpeechManager/SpeechManager.swift`
- `Hakumai/Managers/SpeechManager/AudioLoader.swift`
- `Hakumai/Managers/VoicevoxWrapper/VoicevoxWrapper.swift`
- `Hakumai/Managers/SpeechManager/AudioCacher.swift`

Responsibilities:

- Clean and pre-check comment text before enqueuing.
- Optionally include speaker name in generated speech text.
- Load VOICEVOX audio, cache short utterances, and play in queue order.
- Skip or compress problematic comments (too long, too many emojis/lines, repeated patterns).

Failure behavior:

- If VOICEVOX is unavailable, mark load as failed without crashing the pipeline.
- Retry lost VOICEVOX connections up to a small bounded count.

### 5. Notification Agent

Primary components:

- `Hakumai/Controllers/NotificationPresenter.swift`
- notification calls in `Hakumai/Controllers/MainWindowController/MainViewController.swift`

Responsibilities:

- Request local notification permission.
- Show live-open/live-close notifications with optional thumbnail attachment.
- Route click actions back to live program handling via callback.

### 6. Browser Sync Agent

Primary components:

- `Hakumai/Managers/BrowserUrlObserver/BrowserUrlObserver.swift`
- `Hakumai/Managers/BrowserUrlObserver/IgnoreLiveRegistry.swift`
- handling in `Hakumai/AppDelegate.swift`

Responsibilities:

- Poll active browser URL (Chrome/Safari) at fixed intervals.
- Detect live URLs and trigger connection in existing/new tabs.
- Prevent duplicate connects using temporary ignore registry.
- Optionally focus matching app tab when browser tab selection sync is enabled.

### 7. Ranking Agent

Primary components:

- `Hakumai/Managers/RankingManager/RankingManager.swift`

Responsibilities:

- Poll ranking pages periodically.
- Parse rank data from HTML.
- Maintain rank map and notify registered delegates for each live program.

## End-to-End Flow

1. `MainViewController` requests connection with a live program ID.
2. Session Agent validates token and resolves live metadata + websocket endpoint.
3. Session Agent opens watch socket, then starts NDGR stream ingestion.
4. Stream Ingestion Agent emits history and realtime `Chat` events.
5. Comment Processing Agent updates message state, filtering, and detectors.
6. UI updates table/statistics/title indicators and optional local notifications.
7. Speech Agent enqueues eligible comments when speech mode is active.
8. On socket errors, no-pong, or no-text timeout, reconnect flow is triggered.

## Reliability Rules

- Keep reconnect reasons explicit (`normal`, `noPong`, `noTexts`).
- Preserve deduplication guarantees for NDGR message meta IDs.
- Avoid unbounded buffers and queues.
- Do not block UI thread with network or heavy parse work.
- Ensure delegate callbacks that update UI are marshaled to main thread where needed.

## Security Rules

- Use keychain-backed token storage only.
- Do not persist credentials in plaintext files.
- Minimize OAuth scope usage to required endpoints.
- Review dependency updates for security-impacting changes.

## Testing and Verification

CI reference:

- `.github/workflows/build-test.yml`

Typical local setup:

```sh
bundle install --path=vendor/bundle
bundle exec pod install
cp ./Hakumai/OAuthCredential.sample.swift ./Hakumai/OAuthCredential.swift
xcodebuild -workspace Hakumai.xcworkspace -scheme Hakumai -configuration Debug \
  -destination 'platform=OS X' CODE_SIGN_IDENTITY=\"\" CODE_SIGNING_REQUIRED=NO test
```

## Known Gaps and Future Work

- Some NDGR conversion paths are marked TODO and need production validation.
- Legacy message-socket code remains partially retained in `NicoManager` comments.
- More structured metrics (latency, throughput, failure rates) should be added for monitoring.

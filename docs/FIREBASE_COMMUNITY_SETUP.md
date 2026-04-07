# Firebase Community Setup

This repo now includes Firestore config for the community feature:

- `firebase.json`
- `firestore.rules`
- `firestore.indexes.json`

## What this layer adds

- Signed-in access control for app data already used by the client
- Community-specific Firestore rules for:
  - sphere creation/deletion
  - membership docs
  - posts
  - replies
  - reactions
  - reports
  - warnings
- Owner-only pinning and moderation-oriented read rules

## Important limitation

This is still a client-driven backend. Firestore rules can reduce abuse, but they do not replace trusted server logic for:

- authoritative counters
- moderation escalation
- spam throttling
- notification fan-out
- analytics aggregation

For a production-grade layer, the next step after this file is a Firebase `functions/` project that moves these writes server-side:

- increment/decrement `memberCount`
- maintain `replyCount`
- maintain `reactionCounts`
- maintain `lastActivityText` and `lastActivityAt`
- convert reports/warnings into moderator workflows
- send push notifications for replies and new activity

## Deploy

If Firebase is already connected for this project:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

If Firebase has not been initialized in this repo yet:

```bash
firebase init firestore
```

Then point it at:

- rules: `firestore.rules`
- indexes: `firestore.indexes.json`

## Recommended next server work

1. Add Firebase Cloud Functions for community counters and moderation events.
2. Add FCM notifications for new replies and unread sphere activity.
3. Add moderator-only review tooling for `reports`.
4. Move warning escalation and member removal off the client.

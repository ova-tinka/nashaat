# Bloom — Application Architecture

Bloom is one product with mobile clients for iOS and Android, a Tauri desktop client for macOS, and a shared Supabase backend. Exercise, Education, Reading, and Tasks are peer activity domains. Focus, Screen Time, rewards, identity, and synchronization are shared services.

## Repository structure

```text
src/
├── app/                 Expo Router routes and navigation
├── components/          Shared React Native UI
├── constants/           Product-wide constants
├── hooks/               Lifecycle-aware client hooks
└── lib/                 Domain services, Supabase access, synchronization
modules/
└── bloom-blocking/      Native module interface and platform implementations
native/ios/              Screen Time and Safari extension sources
src-tauri/               macOS host, Network Extension, monitor, and broker
plugins/                 Expo config plugins for native setup
supabase/
├── functions/            Server-side services
└── migrations/           Database schema, policies, and business rules
tests/                    SQL, concurrency, and JavaScript verification
```

## Shared activity and reward flow

Each pillar records a typed activity completion with a stable activity ID. The server validates eligibility and caps, then adds one idempotent entry to the shared credit ledger. A device must reserve credits on the server before its native adapter applies an unlock. The server owns settlement and the authoritative balance; clients display device status and refreshed wallet state.

Focus can attach to a workout, study session, reading session, or task. It may enforce restrictions and record focused time, but it does not create a second reward for the same work. Parent approval, when enabled, keeps a reward pending until approval.

## Platform boundary

React Native views use a shared TypeScript interface for blocking and device status. Native code implements OS-specific controls:

- iOS uses Family Controls, Managed Settings, and Device Activity. App and website targets are selected locally on each device.
- Android uses user-authorized Usage Access and Accessibility integrations with a defined browser support list.
- macOS uses the Tauri host, a Network Extension content filter, and native monitor services.

The three platforms do not offer identical enforcement. The client reports Ready only when the platform confirms active enforcement; missing permissions, stale rules, or unsupported targets are shown as degraded states.

## Data and trust boundaries

Supabase migrations own ledger writes, reward idempotency, session reservations, account relationships, and authorization. Client keys are publishable keys only. Row-level policies and server functions enforce account ownership. Device-local caches may queue activities, but an offline completion remains pending and cannot authorize spending until the server accepts it.

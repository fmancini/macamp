# Security and memory review (2026-11-03)

## Findings and fixes
- Station addresses: only `http` and `https` with a host play (`Player.streamURL`). Before, any scheme parsed by `URL` was accepted.
- Radio Browser mirrors: a DNS name must end in `.radio-browser.info` (was a bare suffix, so `evilradio-browser.info` passed).
- Radio memory: a stream faster than real time queued audio without limit. Now at most 30 s is queued; extra buffers are dropped.
- Undo: the Queue undo stack is limited to 50 levels (each level holds a copy of the Queue).
- Artwork cache: `NSCache` limited to 200 images.
- Recording: stops when the disk has less than 500 MB free.
- CPU: the playhead refreshes every 0.5 s instead of 0.25 s (about 19% to 3% CPU while playing); idle CPU is 0%.

## Known and accepted
- No App Sandbox, ad hoc signature, no hardened runtime. The app is personal, built locally. Sandboxing would need security-scoped bookmarks for folders.
- `NSAllowsArbitraryLoads` is on because many radio stations only offer plain `http`. Only stream and Radio Browser requests use the network; no accounts, no analytics.
- Test hooks (`APP_SEED`, `APP_RADIO`, `APP_PLAYFILE`...) act only when `APP_STORE` points outside the real database folder.

## Memory
64 MB with an empty library, 138 MB with 20,000 tracks.

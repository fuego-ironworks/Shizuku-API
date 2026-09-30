# Shizuku-API D branch

This directory is a whole-hog D translation of the Shizuku-API repository,
pinned by SOURCE.lock. It is not a wrapper around the Java library and it does
not treat one demo as the port.

The Android foreign boundary is owned by Ick DMD on branch
`dmd-shizuku-android-touchpoints`; this tree imports that boundary instead of
copying Binder/Parcel ABI declarations.

## Translated now

- exact Shizuku API constants and Bundle-key strings;
- all four AIDL transaction maps, including explicit high-number method ids;
- Shizuku binder/server state and binder-death semantics;
- permission result semantics;
- UserServiceArgs defaults, null-vs-empty tag keying, add/remove option shaping,
  peek compatibility, and the server-version gate for detach-without-kill;
- ConfigManager flags and abstract contract;
- ClientRecord/ClientManager lookup, permission, add/remove, and death-link
  success/failure semantics, with Binder registration injected at the boundary;
- UserHandle UID splitting;
- ShizukuBinderWrapper v13/pre-v13 flag-forwarding plan;
- ShizukuProvider constants, provider-info validation, binder-sharing decisions,
  and multi-process/Sui state;
- rish tty flags, transaction offsets, configuration, and native-library path
  selection;
- Sui bridge constants;
- initial Binder lifetime/liveness calls through the Ick Android ABI seam;
- semantic unittests for the pure state/protocol layer.

Two early translation drifts were corrected while extending this branch:
`connection_key()` now preserves an explicitly empty Java tag, and binder
death no longer gets confused with a full state reset.

## Important repository boundary

This repository is Shizuku-API. The manager/server application itself lives in
the separate RikkaApps/Shizuku repository. A literal whole-program Shizuku port
also needs that repository. This branch translates the complete API-side tree
available here and keeps that distinction explicit.

See PORTING.md for the remaining map and blockers.

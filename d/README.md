# Shizuku-API D branch

This directory begins a whole-hog D translation of the Shizuku-API repository,
pinned by SOURCE.lock. It is not a wrapper around the Java library and it does
not treat one demo as the port.

The Android foreign boundary is owned by Ick DMD on branch
`dmd-shizuku-android-touchpoints`; this tree imports that boundary instead of
copying Binder/Parcel declarations.

## First translated slice

- exact Shizuku API constants and Bundle-key strings;
- current IShizukuService AIDL method ids and Binder transaction mapping;
- V13 and legacy V11 attachApplication transaction numbers;
- server/binder state transitions used by Shizuku.java;
- permission result semantics;
- UserServiceArgs defaults and connection-key selection;
- initial Binder lifetime/liveness calls through the Ick Android ABI seam;
- semantic tests for the pure state/protocol layer.

See PORTING.md for the repository-wide map and explicit blockers.

## Important repository boundary

This repository is Shizuku-API. The manager/server application itself lives in
the separate RikkaApps/Shizuku repository. A literal whole-program Shizuku port
will also need that repository; this branch translates the complete API side
available here and keeps that distinction explicit.

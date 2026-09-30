# NDK Binder client slice

`service_ndk_client.d` is the first direct libbinder_ndk implementation rather
than a protocol-only model.

Implemented against the Ick Android touchpoint commit pinned in SOURCE.lock:

- getVersion
- getUid
- checkPermission
- getSystemProperty
- setSystemProperty
- requestPermission
- checkSelfPermission
- shouldShowRequestPermissionRationale
- getFlagsForUid
- updateFlagsForUid
- exit

The code uses standard AIDL reply status headers and preserves transport,
exception and payload status separately.

## Binder class requirement

`AIBinder_prepareTransaction` only works after the remote binder has an
`AIBinder_Class` associated with it. The Android boundary now exposes
`AIBinder_Class_define` and `AIBinder_associateClass`, but the Shizuku local
callback class is not wired yet. The client therefore exposes
`associate_transaction_class` and refuses to pretend an unassociated Binder
is transaction-ready.

## API-level boundary

This path is API 29+. It does not replace Shizuku-API's older Android support.
The lower-API compatibility path still needs the Java Binder/JNI bridge.

## Still missing from the NDK client

The methods carrying Bundle, Intent, binder callback interfaces, string arrays,
or remote-process objects need additional codecs and local Binder classes:
attachApplication, newProcess, add/remove/attach user service, package-change
dispatch, permission-confirmation dispatch, and related callbacks.

The Ick compiler also still rejects the external calls needed to execute this
module on ARM. This source records the intended native implementation; it is not
yet device-qualified.

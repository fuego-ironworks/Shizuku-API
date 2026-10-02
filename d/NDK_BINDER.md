# NDK Binder client slice

`service_ndk_client.d` is the first direct libbinder_ndk implementation rather
than a protocol-only model.

Implemented against the Ick Android touchpoint commit pinned in SOURCE.lock.
The shared AIDL transaction/status code lives in `aidl_ndk.d`.

Primitive IShizukuService calls:

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

## Rish raw file-descriptor boundary

`rish_ndk_client.d` now translates the client-side `createHost` transaction:
tty flags, nullable string arrays, working directory, transaction-code offset,
and normal Binder reply/status handling all use the shared D NDK machinery.

One field cannot use the public NDK helper. Upstream Rish writes descriptors
with Java `Parcel.writeFileDescriptor` and reads them with
`Parcel.readFileDescriptor`. `AParcel_writeParcelFileDescriptor` represents
`android.os.ParcelFileDescriptor`, which has different wire framing. The D
client therefore injects a narrow `RishRawFdWriter` boundary instead of
silently substituting the incompatible NDK encoding.

The same distinction applies to the server-side decoder. The raw-FD bridge
belongs in the Android/Ick boundary; the Rish protocol remains unchanged.

## Still missing from the NDK client

`IRemoteProcess` now has a complete native proxy for its three file-descriptor
streams, wait/exit/destroy/alive, and waitForTimeout calls. A local
`IShizukuServiceConnection` Binder class decodes connected/died callbacks; the
connected Binder is borrowed for the callback duration and must be retained
explicitly with `AIBinder_incStrong` if stored. A local `IShizukuApplication`
Binder now handles the two normal-app callbacks as raw Bundle Parcel handoffs.

The legacy V11 attach transaction is implemented natively because its payload
is only application Binder + package name. V13 attach still needs Android
Bundle serialization. Bundle decoding for `bindApplication` and permission
results is deliberately delegated to a framework boundary instead of copying
BaseBundle's private wire implementation.

Still missing are V13 attachApplication, newProcess, add/remove/attach user
service, package-change dispatch, permission-confirmation dispatch, and the
Sui-only synchronous application callback.

The Ick compiler also still rejects the external calls needed to execute this
module on ARM. This source records the intended native implementation; it is not
yet device-qualified.

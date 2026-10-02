# Whole-hog D translation map

The translation preserves the repository by module rather than replacing only
one convenient API surface.

| Original area | D status | Notes |
| --- | --- | --- |
| shared | translated | ShizukuApiConstants translated exactly. |
| aidl | protocol + native clients | All four transaction maps are represented. API-29+ NDK code now covers primitive IShizukuService calls, legacy V11 attach, all IRemoteProcess calls, IShizukuServiceConnection, and raw normal-app IShizukuApplication callbacks. V13 Bundle/Intent/string-array codecs remain. |
| api | substantial | Core state, UserService arguments/launch parsing, client records, service-connection/cache state, system-property parsing, remote-process state, binder-wrapper forwarding, UID helpers and Sui protocol are translated. Android Parcel/Handler/stream adapters remain. |
| provider | protocol/state translated | Constants, BinderContainer holder semantics, manifest invariants and binder-sharing decisions are translated. ContentProvider, Bundle, BroadcastReceiver and Intent adapters remain. |
| server-shared | substantial translation | ConfigManager/entry, ClientRecord/ClientManager, UserService lifecycle, UserServiceManager record tables/replacement/peek/remove/package history, Service permission/request/flag policy and UID helpers are translated. Binder/PackageManager/process/file-descriptor plumbing and Android runtime bootstrapping remain. |
| rish | substantial translation | Constants/config, C-string blocks, environment rules, tty/pipe planning, transaction routing, RishHost object/start marshaling, PID-keyed RishService host state, terminal/native fd behavior and exit semantics are translated. POSIX/Bionic execution, pthread transfer loops and Binder Parcel adapters remain. |
| demo | deferred test consumer | Translate after the API path can execute on device. |
| demo-hidden-api-stub | mapped | Preserve hidden API declarations as an explicit Android boundary. |

## Translation rules

1. Keep Java/AIDL behavior visible beside the D replacement until parity tests
   cover the translated path.
2. Put Android ABI declarations in Ick DMD, not in this repository.
3. Do not substitute a new Binder protocol. Preserve descriptors, transaction
   ids, Bundle keys, permission values and lifecycle behavior.
4. Port logic even when Ick cannot execute it yet; record the exact compiler or
   Android runtime gap instead of silently falling back to Java/Gradle.
5. Prefer direct D -> Android C ABI once qualified. Use JNI only for framework
   surfaces which lack an NDK equivalent or for compatibility below the public
   Binder NDK API level.
6. Keep the current Java tree as provenance until the D tree reaches parity.
7. Preserve Java null-vs-empty distinctions where they affect protocol or cache
   behavior; D slices default to null, so length checks are not equivalent.

## Current hard seam

Ick's Android ARM branch qualifies freestanding scalar leaves, not general
external calls/relocations, Bionic, libbinder_ndk, JNI, druntime or Phobos.
The D source can therefore express the real boundary now, but it cannot yet be
claimed as a runnable Shizuku replacement.

The next executable milestone is call/relocation lowering plus a physical-device
probe that links one D function against libbinder_ndk and liblog. A primitive
IShizukuService NDK proxy is now present in source, so that probe can graduate
from a synthetic ABI call to a real Shizuku transaction once Binder class
association is wired. Bundle/Intent/callback codecs and older-API compatibility
remain separate work.

File-by-file status is tracked in COVERAGE.md.

## Next translation slices independent of that seam

- attachApplication V13 Bundle codec and Bundle callback decoder;
- add/remove/attach user-service Bundle codecs;
- newProcess string-array and returned Binder codec;
- provider ContentProvider/Bundle/Intent/Handler adapters;
- rish POSIX/Bionic fork/pty/transfer implementation;
- server-side Binder stub and Android PackageManager/property/process adapters;

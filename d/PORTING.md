# Whole-hog D translation map

The translation preserves the repository by module rather than replacing only
one convenient API surface.

| Original area | D status | Notes |
| --- | --- | --- |
| shared | translated | ShizukuApiConstants translated exactly. |
| aidl | protocol translated | All four interface transaction maps are represented. Raw Binder proxy/stub Parcel codecs remain. |
| api | substantial | Core state, UserService argument semantics, client records, binder-wrapper forwarding, UID helpers and Sui protocol are translated. Android Parcel/Handler/ServiceConnection adapters remain. |
| provider | protocol/state translated | Constants, manifest invariants and binder-sharing decisions are translated. ContentProvider, Bundle, BroadcastReceiver and Intent adapters remain. |
| server-shared | started | ConfigManager/entry, ClientRecord/ClientManager, UserService record state and UID helpers are translated. UserServiceManager, Service, process/file-descriptor plumbing and Android runtime bootstrapping remain. |
| rish | started | Constants/config/native-library selection translated. Terminal/host JNI and pty implementation remain. |
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
probe that links one D function against libbinder_ndk and liblog. After that,
implement the raw AIDL proxy/stub Parcel codecs, then wire the Java-framework-
only provider/Bundle/Handler pieces.

## Next translation slices independent of that seam

- UserServiceManager record lookup/restart/remove logic;
- Service permission/config dispatch logic;
- ShizukuRemoteProcess semantic wrapper and lifetime state;
- rish host/terminal protocol and pty transfer logic;
- SystemServiceHelper lookup policy;
- provider BinderContainer representation.

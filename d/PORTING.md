# Whole-hog D translation map

The translation preserves the repository by module rather than replacing only
one convenient API surface.

| Original area | D status | Notes |
| --- | --- | --- |
| shared | started | ShizukuApiConstants translated exactly. |
| aidl | started | IShizukuService method ids and Binder transaction mapping recorded; generated proxy/stub behavior remains. |
| api | started | Core server state, permission semantics, UserServiceArgs defaults/keying, and Android Binder boundary begun. |
| provider | mapped | ContentProvider, Bundle, BroadcastReceiver, Intent and multiprocess binder-sharing require JNI/framework touch points. |
| server-shared | mapped | UserService and UserServiceManager still need translation. |
| rish | mapped | Shell protocol/process plumbing still needs translation. |
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

## Current hard seam

Ick's Android ARM branch qualifies freestanding scalar leaves, not general
external calls/relocations, Bionic, libbinder_ndk, JNI, druntime or Phobos.
The D source can therefore express the real boundary now, but it cannot yet be
claimed as a runnable Shizuku replacement.

The next useful compiler work is call/relocation lowering plus a physical-device
probe that links one D function against libbinder_ndk and liblog. After that,
translate the raw AIDL proxy/stub path, then the Java-framework-only provider
and Bundle pieces.

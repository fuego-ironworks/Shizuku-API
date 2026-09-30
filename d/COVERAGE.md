# D translation coverage

Pinned Java/AIDL/C++ source is the tree recorded in SOURCE.lock. "Semantic"
means the behavior is translated but an Android/JNI/Bionic adapter still
stands between it and execution.

| Upstream source | D translation | Status |
| --- | --- | --- |
| shared/ShizukuApiConstants.java | api_constants.d | translated |
| IShizukuService.aidl | service_protocol.d, service_ndk_client.d | primitive calls + V11 attach native; V13 Bundle/newProcess/object calls remain |
| IRemoteProcess.aidl | service_protocol.d, remote_process_ndk_client.d | native proxy translated |
| IShizukuServiceConnection.aidl | service_protocol.d, service_connection_ndk_binder.d | local Binder translated |
| IShizukuApplication.aidl | service_protocol.d, application_ndk_binder.d | normal-app Binder dispatch translated; Bundle decoding and Sui-only synchronous callback remain |
| Shizuku.java | state.d, user_service.d, listeners.d, service_ndk_client.d | substantial; attach Bundle and Android Handler/Binder adapters remain |
| ShizukuBinderWrapper.java | binder_wrapper_protocol.d | semantic framing translated; raw Parcel append/forward adapter remains |
| ShizukuRemoteProcess.java | remote_process.d, remote_process_ndk_client.d | substantial/native proxy |
| ShizukuServiceConnection.java | service_connections.d, service_connection_ndk_binder.d | substantial |
| ShizukuServiceConnections.java | service_connections.d | translated |
| ShizukuSystemProperties.java | system_properties.d, service_ndk_client.d | translated above Binder boundary |
| SystemServiceHelper.java | system_service_policy.d | reflection/cache policy only |
| Sui.java | sui_protocol.d | bridge protocol only |
| BinderContainer.java | binder_container.d | semantic holder; Parcelable adapter remains |
| ShizukuProvider.java | provider_protocol.d | provider policy/state; framework adapter remains |
| ClientRecord.java | client_records.d | translated |
| ClientManager.java | client_records.d | translated except Binder death adapter |
| ConfigManager.java | config.d | translated abstract contract |
| ConfigPackageEntry.java | config.d | translated abstract contract |
| Service.java | service_policy.d | permission/dispatch policy; Binder server/framework calls remain |
| UserService.java | user_service_launch.d | argument parsing; ActivityThread/class-loader bootstrap remains |
| UserServiceManager.java | user_service_manager_policy.d, user_service_registry.d | record tables, replacement/peek/remove/package history translated; Android package validation/process launch remain |
| UserServiceRecord.java | user_service.d | lifecycle/start-timeout/destroy decisions translated; Binder callback delivery/timer scheduling remain |
| RemoteProcessHolder.java | remote_process.d | timeout/lifetime semantics; Process/PFD adapter remains |
| AbiUtil.java | abi_util.d | translated with boundary-supplied ABI count |
| HandlerUtil.java | handler_slot.d | translated opaque slot |
| OsUtils.java | state/boundary | uid/pid/SELinux acquisition remains |
| ParcelFileDescriptorUtil.java | remote/rish boundary | transfer implementation remains |
| Logger.java | Android log boundary | formatting/file logger remains |
| UserHandleCompat.java | user_handle.d | translated |
| Rish.java | rish_entry.d | control flow translated |
| RishConfig.java / RishConstants.java | rish_config.d | translated |
| RishHost.java | rish_host_policy.d | byte packing/state translated; native fork/pty remains |
| RishService.java | rish_service_policy.d | transaction/environment policy translated |
| RishTerminal.java | rish_terminal_policy.d | tty/fd policy translated; native terminal loop remains |
| rish C++ PTY/JNI files | rish_*_policy.d | semantics mapped; POSIX/Bionic implementation remains |

The remaining concentration of work is no longer ordinary Java business logic.
It is Android framework serialization/callback plumbing, Binder server code,
and the native Bionic/PTY execution path.

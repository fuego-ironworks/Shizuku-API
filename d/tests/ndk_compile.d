module ndk_compile;

import ick.android;
import shizuku.aidl_ndk;
import shizuku.api_constants : BINDER_DESCRIPTOR;
import shizuku.remote_process_ndk_client :
    REMOTE_PROCESS_DESCRIPTOR,
    define_remote_process_class;
import shizuku.service_connection_ndk_binder :
    SERVICE_CONNECTION_DESCRIPTOR,
    define_service_connection_class;
import shizuku.service_ndk_client : define_shizuku_service_class;
import shizuku.service_protocol :
    RemoteProcessTransaction,
    ServiceConnectionTransaction;

static assert(BINDER_DESCRIPTOR == "moe.shizuku.server.IShizukuService");
static assert(REMOTE_PROCESS_DESCRIPTOR == "moe.shizuku.server.IRemoteProcess");
static assert(SERVICE_CONNECTION_DESCRIPTOR ==
    "moe.shizuku.server.IShizukuServiceConnection");
static assert(RemoteProcessTransaction.wait_for_timeout == 8);
static assert(ServiceConnectionTransaction.connected == 1);
static assert(ServiceConnectionTransaction.died == 2);

/**
 * Compile-only signature probe. It deliberately does not call libbinder_ndk;
 * the Ick ARM backend does not yet qualify external calls/relocations.
 */
extern(C) int shizuku_ndk_compile_probe(AIBinder* binder)
{
    return binder is null ? -1 : 0;
}

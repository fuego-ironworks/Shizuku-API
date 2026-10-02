module shizuku.rish_service_native;

import ick.android :
    AIBinder_getCallingPid,
    STATUS_BAD_VALUE,
    STATUS_NO_MEMORY,
    STATUS_OK,
    STATUS_PERMISSION_DENIED,
    binder_status_t;
import ick.android.bionic :
    SIGKILL,
    free,
    getuid,
    kill,
    malloc,
    pthread_create,
    pthread_t;
import shizuku.rish_host :
    RishHostStartInput;
import shizuku.rish_host_native :
    RishNativeStartResult,
    start_host;
import shizuku.rish_bionic :
    set_window_size,
    wait_for_child;
import shizuku.rish_ndk_server :
    OwnedUtf8,
    OwnedUtf8Array,
    RishBinderServerContext,
    RishCreateHostView,
    RishPermissionHandler,
    RishRawFdReader;
import shizuku.rish_service_policy :
    RishTransaction;

private enum string PRESERVE_ENV = "RISH_PRESERVE_ENV=1";
private enum string DROP_ENV = "RISH_PRESERVE_ENV=0";

private struct NativeRishHost {
    int pid;
    int ptmx = -1;
    int exit_code = int.max;
}

private struct NativeRishHostSlot {
    int calling_pid;
    NativeRishHost* host;
    NativeRishHostSlot* next;
}

/**
 * Process-wide native replacement for RishService.HOSTS plus its root/env
 * policy. The optional permission callback corresponds to the abstract Java
 * enforceCallingPermission hook.
 */
struct RishServiceRuntime {
    bool is_root;
    NativeRishHostSlot* hosts;

    RishPermissionHandler permission;
    void* permission_context;
}

private bool utf8_equals(
    const ref OwnedUtf8 value,
    string expected) nothrow @nogc
{
    if (value.is_null || value.length != cast(int) expected.length)
        return false;

    foreach (i; 0 .. expected.length) {
        if (value.buffer[i] != expected[i])
            return false;
    }
    return true;
}

private bool preserve_environment(
    bool is_root,
    const ref OwnedUtf8Array environment) nothrow @nogc
{
    bool allow = is_root;

    if (environment.is_null || environment.values is null)
        return allow;

    foreach (i; 0 .. cast(size_t) environment.length) {
        const value = environment.values[i];
        if (utf8_equals(value, PRESERVE_ENV))
            return true;
        if (utf8_equals(value, DROP_ENV))
            return false;
    }
    return allow;
}

private bool pack_array(
    const ref OwnedUtf8Array values,
    out ubyte[] block) nothrow @nogc
{
    block = null;
    if (values.is_null || values.length < 0)
        return false;

    size_t total = cast(size_t) values.length;
    foreach (i; 0 .. cast(size_t) values.length) {
        const value = values.values[i];
        if (value.is_null || value.length < 0 || value.buffer is null)
            return false;

        const size_t length = cast(size_t) value.length;
        if (total > size_t.max - length)
            return false;
        total += length;
    }

    if (total == 0)
        return true;

    auto data = cast(ubyte*) malloc(total);
    if (data is null)
        return false;

    block = data[0 .. total];
    size_t offset;

    foreach (i; 0 .. cast(size_t) values.length) {
        const value = values.values[i];
        foreach (j; 0 .. cast(size_t) value.length)
            block[offset++] = cast(ubyte) value.buffer[j];
        block[offset++] = 0;
    }
    return true;
}

private bool pack_string(
    const ref OwnedUtf8 value,
    out ubyte[] block) nothrow @nogc
{
    block = null;
    if (value.is_null)
        return true;
    if (value.length < 0 || value.buffer is null)
        return false;

    const size_t length = cast(size_t) value.length;
    if (length == size_t.max)
        return false;

    auto data = cast(ubyte*) malloc(length + 1);
    if (data is null)
        return false;

    block = data[0 .. length + 1];
    foreach (i; 0 .. length)
        block[i] = cast(ubyte) value.buffer[i];
    block[length] = 0;
    return true;
}

private void release_block(ref ubyte[] block) nothrow @nogc
{
    if (block.ptr !is null)
        free(block.ptr);
    block = null;
}

private NativeRishHostSlot* find_slot(
    RishServiceRuntime* runtime,
    int calling_pid) nothrow @nogc
{
    if (runtime is null)
        return null;

    auto slot = runtime.hosts;
    while (slot !is null) {
        if (slot.calling_pid == calling_pid)
            return slot;
        slot = slot.next;
    }
    return null;
}

extern(C) private void* wait_host_main(void* raw) nothrow @nogc
{
    auto host = cast(NativeRishHost*) raw;
    if (host !is null)
        host.exit_code = wait_for_child(host.pid);
    return null;
}

extern(C) private binder_status_t runtime_permission(
    void* raw,
    RishTransaction transaction) nothrow @nogc
{
    auto runtime = cast(RishServiceRuntime*) raw;
    if (runtime is null || runtime.permission is null)
        return STATUS_PERMISSION_DENIED;

    return runtime.permission(
        runtime.permission_context,
        transaction
    );
}

extern(C) private binder_status_t runtime_create_host(
    void* raw,
    RishCreateHostView* request) nothrow @nogc
{
    auto runtime = cast(RishServiceRuntime*) raw;
    if (runtime is null || request is null)
        return STATUS_BAD_VALUE;

    // Java createHost iterates env before it can decide to drop it.
    if (request.args.is_null || request.environment.is_null)
        return STATUS_BAD_VALUE;

    RishHostStartInput input;
    input.argc = request.args.length;
    input.tty = request.tty;
    input.stdin_fd = request.stdin_fd;
    input.stdout_fd = request.stdout_fd;
    input.stderr_fd = request.stderr_fd;

    if (!pack_array(request.args, input.arg_block))
        return STATUS_NO_MEMORY;

    const bool keep_environment =
        preserve_environment(runtime.is_root, request.environment);

    if (keep_environment) {
        input.envc = request.environment.length;
        if (!pack_array(request.environment, input.env_block)) {
            release_block(input.arg_block);
            return STATUS_NO_MEMORY;
        }
    } else {
        input.envc = -1;
        input.env_block = null;
    }

    if (!pack_string(request.directory, input.dir_block)) {
        release_block(input.arg_block);
        release_block(input.env_block);
        return STATUS_NO_MEMORY;
    }

    auto host = cast(NativeRishHost*) malloc(NativeRishHost.sizeof);
    if (host is null) {
        release_block(input.arg_block);
        release_block(input.env_block);
        release_block(input.dir_block);
        return STATUS_NO_MEMORY;
    }
    *host = NativeRishHost.init;

    const int calling_pid = AIBinder_getCallingPid();
    auto slot = find_slot(runtime, calling_pid);
    bool new_slot;
    if (slot is null) {
        slot = cast(NativeRishHostSlot*) malloc(NativeRishHostSlot.sizeof);
        if (slot is null) {
            free(host);
            release_block(input.arg_block);
            release_block(input.env_block);
            release_block(input.dir_block);
            return STATUS_NO_MEMORY;
        }
        *slot = NativeRishHostSlot.init;
        new_slot = true;
    }

    const RishNativeStartResult started = start_host(input);

    release_block(input.arg_block);
    release_block(input.env_block);
    release_block(input.dir_block);

    if (!started.ok) {
        if (new_slot)
            free(slot);
        free(host);
        return STATUS_BAD_VALUE;
    }

    /*
     * start_host has handed these descriptors to transfer threads. Mark them
     * consumed so the Binder decoder will not close them a second time.
     */
    request.stdin_fd = -1;
    request.stdout_fd = -1;
    request.stderr_fd = -1;

    host.pid = started.pid;
    host.ptmx = started.ptmx;
    host.exit_code = int.max;

    pthread_t waiter;
    if (pthread_create(&waiter, null, &wait_host_main, host) != 0) {
        /*
         * Java would fail while starting its waiter after the child already
         * exists. Do not claim the host in the PID table; preserve that ordering.
         */
        if (new_slot)
            free(slot);
        free(host);
        return STATUS_NO_MEMORY;
    }

    // HashMap.put(callingPid, host), after host.start() has completed.
    if (new_slot) {
        slot.calling_pid = calling_pid;
        slot.next = runtime.hosts;
        runtime.hosts = slot;
    }
    slot.host = host;

    return STATUS_OK;
}

extern(C) private binder_status_t runtime_set_window_size(
    void* raw,
    long packed_size) nothrow @nogc
{
    auto runtime = cast(RishServiceRuntime*) raw;
    if (runtime is null)
        return STATUS_BAD_VALUE;

    auto slot = find_slot(runtime, AIBinder_getCallingPid());
    if (slot is null || slot.host is null)
        return STATUS_OK;

    // Java ignores the native setWindowSize return value.
    set_window_size(slot.host.ptmx, packed_size);
    return STATUS_OK;
}

extern(C) private binder_status_t runtime_get_exit_code(
    void* raw,
    int* exit_code) nothrow @nogc
{
    auto runtime = cast(RishServiceRuntime*) raw;
    if (runtime is null || exit_code is null)
        return STATUS_BAD_VALUE;

    auto slot = find_slot(runtime, AIBinder_getCallingPid());
    *exit_code = slot is null || slot.host is null
        ? -1
        : slot.host.exit_code;
    return STATUS_OK;
}

/**
 * Wire the native service runtime into a Rish Binder server context.
 *
 * raw_fd_reader remains an Android/platform bridge because the stable NDK
 * exposes ParcelFileDescriptor framing, not Java Parcel.readFileDescriptor's
 * raw Binder FD object.
 */
bool initialize_rish_service_server(
    RishBinderServerContext* server,
    RishServiceRuntime* runtime,
    int transaction_code_start,
    RishRawFdReader raw_fd_reader,
    RishPermissionHandler permission,
    void* permission_context) nothrow @nogc
{
    if (server is null || runtime is null || raw_fd_reader is null)
        return false;

    *runtime = RishServiceRuntime.init;
    runtime.is_root = getuid() == 0;
    runtime.permission = permission;
    runtime.permission_context = permission_context;

    *server = RishBinderServerContext.init;
    server.transaction_code_start = transaction_code_start;
    server.context = runtime;
    server.read_raw_fd = raw_fd_reader;
    server.enforce_permission = &runtime_permission;
    server.create_host = &runtime_create_host;
    server.set_window_size = &runtime_set_window_size;
    server.get_exit_code = &runtime_get_exit_code;
    return true;
}

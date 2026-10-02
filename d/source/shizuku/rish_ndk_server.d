module shizuku.rish_ndk_server;

import ick.android;
import ick.android.bionic :
    close,
    free,
    malloc;
import shizuku.rish_config :
    ATTY_ERR,
    TRANSACTION_CREATE_HOST,
    TRANSACTION_GET_EXIT_CODE,
    TRANSACTION_SET_WINDOW_SIZE;
import shizuku.rish_service_policy :
    RishTransaction,
    classify_rish_transaction;

alias RishRawFdReader =
    extern(C) binder_status_t function(
        const(AParcel)* parcel,
        int* owned_fd
    ) nothrow @nogc;

alias RishPermissionHandler =
    extern(C) binder_status_t function(
        void* context,
        RishTransaction transaction
    ) nothrow @nogc;

alias RishCreateHostHandler =
    extern(C) binder_status_t function(
        void* context,
        RishCreateHostView* request
    ) nothrow @nogc;

alias RishSetWindowSizeHandler =
    extern(C) binder_status_t function(
        void* context,
        long packed_size
    ) nothrow @nogc;

alias RishGetExitCodeHandler =
    extern(C) binder_status_t function(
        void* context,
        int* exit_code
    ) nothrow @nogc;

struct OwnedUtf8 {
    char* buffer;
    int length;
    bool is_null;

    void release() nothrow @nogc
    {
        if (buffer !is null)
            free(buffer);
        buffer = null;
        length = 0;
        is_null = false;
    }
}

struct OwnedUtf8Array {
    OwnedUtf8* values;
    int length;
    bool is_null;

    void release() nothrow @nogc
    {
        if (values !is null) {
            foreach (i; 0 .. cast(size_t) length)
                values[i].release();
            free(values);
        }
        values = null;
        length = 0;
        is_null = false;
    }
}

struct RishCreateHostView {
    ubyte tty;
    int stdin_fd = -1;
    int stdout_fd = -1;
    int stderr_fd = -1;

    OwnedUtf8Array args;
    OwnedUtf8Array environment;
    OwnedUtf8 directory;
}

struct RishBinderServerContext {
    int transaction_code_start;
    void* context;

    /**
     * Must reproduce Java Parcel.readFileDescriptor ownership: return an
     * independently owned fd suitable for transfer to RishHostState.
     */
    RishRawFdReader read_raw_fd;
    RishPermissionHandler enforce_permission;
    RishCreateHostHandler create_host;
    RishSetWindowSizeHandler set_window_size;
    RishGetExitCodeHandler get_exit_code;
}

extern(C) private bool owned_string_allocator(
    void* string_data,
    int length,
    char** output_buffer) nothrow @nogc
{
    auto value = cast(OwnedUtf8*) string_data;
    if (value is null || output_buffer is null)
        return false;

    *value = OwnedUtf8.init;

    if (length == -1) {
        value.is_null = true;
        value.length = -1;
        *output_buffer = null;
        return true;
    }

    if (length <= 0)
        return false;

    value.buffer = cast(char*) malloc(cast(size_t) length);
    if (value.buffer is null)
        return false;

    value.length = length - 1;
    *output_buffer = value.buffer;
    return true;
}

extern(C) private bool owned_array_allocator(
    void* array_data,
    int length) nothrow @nogc
{
    auto array = cast(OwnedUtf8Array*) array_data;
    if (array is null)
        return false;

    *array = OwnedUtf8Array.init;

    if (length == -1) {
        array.is_null = true;
        array.length = -1;
        return true;
    }

    if (length < 0)
        return false;

    array.length = length;
    if (length == 0)
        return true;

    array.values = cast(OwnedUtf8*) malloc(
        cast(size_t) length * OwnedUtf8.sizeof
    );
    if (array.values is null) {
        array.length = 0;
        return false;
    }

    foreach (i; 0 .. cast(size_t) length)
        array.values[i] = OwnedUtf8.init;
    return true;
}

extern(C) private bool owned_array_element_allocator(
    void* array_data,
    size_t index,
    int length,
    char** output_buffer) nothrow @nogc
{
    auto array = cast(OwnedUtf8Array*) array_data;
    if (array is null || output_buffer is null
            || array.values is null
            || index >= cast(size_t) array.length)
        return false;

    auto value = &array.values[index];
    *value = OwnedUtf8.init;

    if (length == -1) {
        value.is_null = true;
        value.length = -1;
        *output_buffer = null;
        return true;
    }

    if (length <= 0)
        return false;

    value.buffer = cast(char*) malloc(cast(size_t) length);
    if (value.buffer is null)
        return false;

    value.length = length - 1;
    *output_buffer = value.buffer;
    return true;
}

private binder_status_t read_owned_array(
    const(AParcel)* input,
    ref OwnedUtf8Array value) nothrow @nogc
{
    value = OwnedUtf8Array.init;
    return AParcel_readStringArray(
        input,
        &value,
        &owned_array_allocator,
        &owned_array_element_allocator
    );
}

private binder_status_t read_owned_string(
    const(AParcel)* input,
    ref OwnedUtf8 value) nothrow @nogc
{
    value = OwnedUtf8.init;
    return AParcel_readString(
        input,
        &value,
        &owned_string_allocator
    );
}

private void close_request_fds(
    ref RishCreateHostView request) nothrow @nogc
{
    if (request.stdin_fd >= 0)
        close(request.stdin_fd);
    if (request.stdout_fd >= 0)
        close(request.stdout_fd);
    if (request.stderr_fd >= 0)
        close(request.stderr_fd);

    request.stdin_fd = -1;
    request.stdout_fd = -1;
    request.stderr_fd = -1;
}

private void release_request_strings(
    ref RishCreateHostView request) nothrow @nogc
{
    request.args.release();
    request.environment.release();
    request.directory.release();
}

private binder_status_t read_create_host(
    const(AParcel)* input,
    RishBinderServerContext* server,
    ref RishCreateHostView request) nothrow @nogc
{
    request = RishCreateHostView.init;

    if (input is null || server is null || server.read_raw_fd is null)
        return STATUS_BAD_VALUE;

    int tty;
    binder_status_t status = AParcel_readInt32(input, &tty);
    if (status != STATUS_OK)
        return status;
    request.tty = cast(ubyte) tty;

    status = server.read_raw_fd(input, &request.stdin_fd);
    if (status != STATUS_OK)
        return status;

    status = server.read_raw_fd(input, &request.stdout_fd);
    if (status != STATUS_OK)
        return status;

    if ((request.tty & ATTY_ERR) == 0) {
        status = server.read_raw_fd(input, &request.stderr_fd);
        if (status != STATUS_OK)
            return status;
    }

    status = read_owned_array(input, request.args);
    if (status != STATUS_OK)
        return status;

    status = read_owned_array(input, request.environment);
    if (status != STATUS_OK)
        return status;

    return read_owned_string(input, request.directory);
}

private binder_status_t write_no_exception(
    AParcel* output) nothrow @nogc
{
    if (output is null)
        return STATUS_OK;

    // Java Parcel.writeNoException writes EX_NONE == 0 first.
    return AParcel_writeInt32(output, 0);
}

private binder_status_t handle_create_host(
    const(AParcel)* input,
    AParcel* output,
    RishBinderServerContext* server) nothrow @nogc
{
    // Mirrors Java's early return when reply is null / oneway.
    if (output is null)
        return STATUS_OK;

    RishCreateHostView request;
    binder_status_t status = read_create_host(input, server, request);
    if (status != STATUS_OK) {
        close_request_fds(request);
        release_request_strings(request);
        return status;
    }

    if (server.create_host is null) {
        close_request_fds(request);
        release_request_strings(request);
        return STATUS_UNKNOWN_TRANSACTION;
    }

    /*
     * Descriptor ownership starts in this adapter. A handler that consumes a
     * descriptor sets its field to -1 before returning; every descriptor still
     * present is closed here. This also handles the rare case where native
     * process start succeeded but a later host-registration step failed.
     *
     * Strings are borrowed only for the callback and are always released here.
     */
    status = server.create_host(server.context, &request);
    close_request_fds(request);
    release_request_strings(request);

    if (status != STATUS_OK)
        return status;
    return write_no_exception(output);
}

private binder_status_t handle_set_window_size(
    const(AParcel)* input,
    AParcel* output,
    RishBinderServerContext* server) nothrow @nogc
{
    if (server.set_window_size is null)
        return STATUS_UNKNOWN_TRANSACTION;

    long packed_size;
    binder_status_t status = AParcel_readInt64(input, &packed_size);
    if (status != STATUS_OK)
        return status;

    status = server.set_window_size(server.context, packed_size);
    if (status != STATUS_OK)
        return status;

    return write_no_exception(output);
}

private binder_status_t handle_get_exit_code(
    AParcel* output,
    RishBinderServerContext* server) nothrow @nogc
{
    if (server.get_exit_code is null)
        return STATUS_UNKNOWN_TRANSACTION;

    int exit_code;
    binder_status_t status =
        server.get_exit_code(server.context, &exit_code);
    if (status != STATUS_OK)
        return status;

    if (output is null)
        return STATUS_OK;

    status = write_no_exception(output);
    if (status != STATUS_OK)
        return status;
    return AParcel_writeInt32(output, exit_code);
}

extern(C) private void* rish_server_on_create(
    void* args) nothrow @nogc
{
    return args;
}

extern(C) private void rish_server_on_destroy(
    void* user_data) nothrow @nogc
{
    // Context storage is caller-owned and must outlive the Binder.
}

extern(C) private binder_status_t rish_server_on_transact(
    AIBinder* binder,
    transaction_code_t code,
    const(AParcel)* input,
    AParcel* output) nothrow @nogc
{
    if (binder is null || input is null)
        return STATUS_BAD_VALUE;

    auto server =
        cast(RishBinderServerContext*) AIBinder_getUserData(binder);
    if (server is null)
        return STATUS_BAD_VALUE;

    const transaction = classify_rish_transaction(
        cast(int) code,
        server.transaction_code_start
    );
    if (transaction == RishTransaction.none)
        return STATUS_UNKNOWN_TRANSACTION;

    if (server.enforce_permission !is null) {
        const binder_status_t permission_status =
            server.enforce_permission(server.context, transaction);
        if (permission_status != STATUS_OK)
            return permission_status;
    }

    final switch (transaction) {
    case RishTransaction.create_host:
        return handle_create_host(input, output, server);

    case RishTransaction.set_window_size:
        return handle_set_window_size(input, output, server);

    case RishTransaction.get_exit_code:
        return handle_get_exit_code(output, server);

    case RishTransaction.none:
        return STATUS_UNKNOWN_TRANSACTION;
    }
}

AIBinder_Class* define_rish_server_class(
    const(char)* interface_descriptor) nothrow @nogc
{
    if (interface_descriptor is null)
        return null;

    return AIBinder_Class_define(
        interface_descriptor,
        &rish_server_on_create,
        &rish_server_on_destroy,
        &rish_server_on_transact
    );
}

AIBinder* new_rish_server_binder(
    const(AIBinder_Class)* server_class,
    RishBinderServerContext* server) nothrow @nogc
{
    if (server_class is null || server is null)
        return null;

    return AIBinder_new(server_class, server);
}

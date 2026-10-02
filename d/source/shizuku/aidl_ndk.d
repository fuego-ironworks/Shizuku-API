module shizuku.aidl_ndk;

import ick.android;

/**
 * Result of one standard AIDL NDK transaction.
 */
struct AidlCallStatus {
    binder_status_t transport_status = STATUS_OK;
    binder_status_t header_status = STATUS_OK;
    binder_status_t payload_status = STATUS_OK;
    binder_exception_t exception_code;
    binder_status_t service_status;
    bool interface_ok = true;
    bool aidl_ok;

    pure nothrow @nogc bool ok() const
    {
        return transport_status == STATUS_OK
            && header_status == STATUS_OK
            && payload_status == STATUS_OK
            && interface_ok
            && aidl_ok;
    }
}

struct Utf8Sink {
    char* buffer;
    int capacity;
    int length;
    bool is_null;
}

struct Utf8View {
    const(char)* buffer;
    int length;
    bool is_null;

    pure nothrow @nogc bool valid() const
    {
        return is_null || (length >= 0 && (length == 0 || buffer !is null));
    }
}

/** Caller-owned UTF-8 array view for AParcel_writeStringArray. */
struct Utf8ArrayView {
    const(Utf8View)* values;
    int length;
    bool is_null;

    pure nothrow @nogc bool valid() const
    {
        if (is_null)
            return true;
        if (length < 0 || (length > 0 && values is null))
            return false;

        foreach (i; 0 .. cast(size_t) length) {
            if (!values[i].valid())
                return false;
        }
        return true;
    }
}

extern(C) const(char)* utf8_array_element_getter(
    const(void)* array_data,
    size_t index,
    int* out_length) nothrow @nogc
{
    if (array_data is null || out_length is null)
        return null;

    auto view = cast(const(Utf8ArrayView)*) array_data;
    if (view.is_null || index >= cast(size_t) view.length)
        return null;

    const(Utf8View) element = view.values[index];
    *out_length = element.is_null ? -1 : element.length;
    return element.is_null ? null : element.buffer;
}

extern(C) bool utf8_sink_allocator(
    void* string_data,
    int length,
    char** output_buffer) nothrow @nogc
{
    auto sink = cast(Utf8Sink*) string_data;
    if (sink is null)
        return false;

    if (length == -1) {
        sink.length = -1;
        sink.is_null = true;
        if (output_buffer !is null)
            *output_buffer = null;
        return true;
    }

    // NDK supplies a length including the terminating NUL.
    if (length <= 0 || length > sink.capacity || sink.buffer is null
            || output_buffer is null)
        return false;

    sink.length = length - 1;
    sink.is_null = false;
    *output_buffer = sink.buffer;
    return true;
}

void delete_parcel(AParcel* parcel) nothrow @nogc
{
    if (parcel !is null)
        AParcel_delete(parcel);
}

bool aidl_prepare(
    AIBinder* binder,
    AParcel** input,
    ref AidlCallStatus call) nothrow @nogc
{
    if (binder is null || input is null) {
        call.interface_ok = false;
        call.aidl_ok = false;
        return false;
    }

    if (AIBinder_getClass(binder) is null) {
        call.interface_ok = false;
        call.aidl_ok = false;
        return false;
    }

    *input = null;
    call.transport_status = AIBinder_prepareTransaction(binder, input);
    return call.transport_status == STATUS_OK && *input !is null;
}

bool aidl_finish(
    AIBinder* binder,
    transaction_code_t code,
    AParcel** input,
    AParcel** output,
    ref AidlCallStatus call,
    binder_flags_t flags = 0) nothrow @nogc
{
    if (binder is null || input is null || output is null) {
        call.aidl_ok = false;
        return false;
    }

    *output = null;
    call.transport_status = AIBinder_transact(binder, code, input, output, flags);
    if (call.transport_status != STATUS_OK || *output is null)
        return false;

    AStatus* remote_status = null;
    call.header_status = AParcel_readStatusHeader(*output, &remote_status);
    if (call.header_status != STATUS_OK || remote_status is null)
        return false;

    call.aidl_ok = AStatus_isOk(remote_status);
    call.exception_code = AStatus_getExceptionCode(remote_status);
    call.service_status = AStatus_getStatus(remote_status);
    AStatus_delete(remote_status);

    return call.aidl_ok;
}

nothrow @nogc bool has_transaction_class(AIBinder* binder)
{
    return binder !is null && AIBinder_getClass(binder) !is null;
}

bool associate_transaction_class(
    AIBinder* binder,
    const(AIBinder_Class)* interface_class) nothrow @nogc
{
    return binder !is null
        && interface_class !is null
        && AIBinder_associateClass(binder, interface_class);
}

extern(C) private void* remote_class_on_create(void* args) nothrow @nogc
{
    return args;
}

extern(C) private void remote_class_on_destroy(void* user_data) nothrow @nogc
{
}

extern(C) private binder_status_t remote_class_on_transact(
    AIBinder* binder,
    transaction_code_t code,
    const(AParcel)* input,
    AParcel* output) nothrow @nogc
{
    return STATUS_UNKNOWN_TRANSACTION;
}

/**
 * Define a class used only to associate a remote Binder with an AIDL descriptor.
 * Call once per interface and retain the returned class for process lifetime.
 */
AIBinder_Class* define_remote_interface_class(const(char)* descriptor) nothrow @nogc
{
    if (descriptor is null)
        return null;

    return AIBinder_Class_define(
        descriptor,
        &remote_class_on_create,
        &remote_class_on_destroy,
        &remote_class_on_transact
    );
}

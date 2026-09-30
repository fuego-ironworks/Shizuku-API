module shizuku.service_ndk_client;

import ick.android;
import shizuku.service_protocol : ServiceMethodId, transaction;

/**
 * Result of one standard AIDL NDK transaction.
 *
 * transport_status is from prepare/transact.
 * header_status is from AParcel_readStatusHeader.
 * exception_code/service_status preserve Java/AIDL exception information.
 * payload_status is the primitive/string read or write status.
 */
struct AidlCallStatus {
    binder_status_t transport_status = STATUS_OK;
    binder_status_t header_status = STATUS_OK;
    binder_status_t payload_status = STATUS_OK;
    binder_exception_t exception_code;
    binder_status_t service_status;
    bool aidl_ok;

    pure nothrow @nogc bool ok() const
    {
        return transport_status == STATUS_OK
            && header_status == STATUS_OK
            && payload_status == STATUS_OK
            && aidl_ok;
    }
}

struct Utf8Sink {
    char* buffer;
    int capacity;
    int length;
    bool is_null;
}

extern(C) private bool utf8_sink_allocator(
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

    if (length <= 0 || length > sink.capacity || sink.buffer is null)
        return false;

    sink.length = length - 1; // allocator length includes terminating NUL
    sink.is_null = false;

    if (output_buffer is null)
        return false;

    *output_buffer = sink.buffer;
    return true;
}

pure nothrow @nogc bool has_transaction_class(AIBinder* binder)
{
    return binder !is null && AIBinder_getClass(binder) !is null;
}

bool associate_transaction_class(
    AIBinder* binder,
    const AIBinder_Class* service_class) nothrow @nogc
{
    return binder !is null
        && service_class !is null
        && AIBinder_associateClass(binder, service_class);
}

private void delete_if_present(AParcel* parcel) nothrow @nogc
{
    if (parcel !is null)
        AParcel_delete(parcel);
}

private bool prepare(
    AIBinder* binder,
    AParcel** input,
    ref AidlCallStatus call) nothrow @nogc
{
    if (binder is null || input is null) {
        call.aidl_ok = false;
        return false;
    }

    *input = null;
    call.transport_status = AIBinder_prepareTransaction(binder, input);
    return call.transport_status == STATUS_OK && *input !is null;
}

private bool finish(
    AIBinder* binder,
    transaction_code_t code,
    AParcel** input,
    AParcel** output,
    ref AidlCallStatus call) nothrow @nogc
{
    *output = null;
    call.transport_status = AIBinder_transact(binder, code, input, output, 0);
    if (call.transport_status != STATUS_OK || *output is null)
        return false;

    AStatus* remote_status;
    call.header_status = AParcel_readStatusHeader(*output, &remote_status);
    if (call.header_status != STATUS_OK || remote_status is null)
        return false;

    call.aidl_ok = AStatus_isOk(remote_status);
    call.exception_code = AStatus_getExceptionCode(remote_status);
    call.service_status = AStatus_getStatus(remote_status);
    AStatus_delete(remote_status);

    return call.aidl_ok;
}

private bool read_int_no_args(
    AIBinder* binder,
    ServiceMethodId method,
    out int value,
    out AidlCallStatus call) nothrow @nogc
{
    call = AidlCallStatus.init;
    value = 0;

    AParcel* input;
    if (!prepare(binder, &input, call))
        return false;

    AParcel* output;
    if (!finish(binder, transaction(method), &input, &output, call)) {
        delete_if_present(output);
        return false;
    }

    call.payload_status = AParcel_readInt32(output, &value);
    delete_if_present(output);
    return call.ok();
}

private bool read_bool_no_args(
    AIBinder* binder,
    ServiceMethodId method,
    out bool value,
    out AidlCallStatus call) nothrow @nogc
{
    call = AidlCallStatus.init;
    value = false;

    AParcel* input;
    if (!prepare(binder, &input, call))
        return false;

    AParcel* output;
    if (!finish(binder, transaction(method), &input, &output, call)) {
        delete_if_present(output);
        return false;
    }

    call.payload_status = AParcel_readBool(output, &value);
    delete_if_present(output);
    return call.ok();
}

bool get_version(
    AIBinder* binder,
    out int value,
    out AidlCallStatus call) nothrow @nogc
{
    return read_int_no_args(binder, ServiceMethodId.get_version, value, call);
}

bool get_uid(
    AIBinder* binder,
    out int value,
    out AidlCallStatus call) nothrow @nogc
{
    return read_int_no_args(binder, ServiceMethodId.get_uid, value, call);
}

bool check_self_permission(
    AIBinder* binder,
    out bool value,
    out AidlCallStatus call) nothrow @nogc
{
    return read_bool_no_args(
        binder,
        ServiceMethodId.check_self_permission,
        value,
        call
    );
}

bool should_show_request_permission_rationale(
    AIBinder* binder,
    out bool value,
    out AidlCallStatus call) nothrow @nogc
{
    return read_bool_no_args(
        binder,
        ServiceMethodId.should_show_request_permission_rationale,
        value,
        call
    );
}

bool check_permission(
    AIBinder* binder,
    const char* permission,
    int permission_length,
    out int result,
    out AidlCallStatus call) nothrow @nogc
{
    call = AidlCallStatus.init;
    result = 0;

    AParcel* input;
    if (!prepare(binder, &input, call))
        return false;

    call.payload_status =
        AParcel_writeString(input, permission, permission_length);
    if (call.payload_status != STATUS_OK) {
        delete_if_present(input);
        return false;
    }

    AParcel* output;
    if (!finish(
            binder,
            transaction(ServiceMethodId.check_permission),
            &input,
            &output,
            call)) {
        delete_if_present(output);
        return false;
    }

    call.payload_status = AParcel_readInt32(output, &result);
    delete_if_present(output);
    return call.ok();
}

bool request_permission(
    AIBinder* binder,
    int request_code,
    out AidlCallStatus call) nothrow @nogc
{
    call = AidlCallStatus.init;

    AParcel* input;
    if (!prepare(binder, &input, call))
        return false;

    call.payload_status = AParcel_writeInt32(input, request_code);
    if (call.payload_status != STATUS_OK) {
        delete_if_present(input);
        return false;
    }

    AParcel* output;
    const bool result = finish(
        binder,
        transaction(ServiceMethodId.request_permission),
        &input,
        &output,
        call
    );
    delete_if_present(output);
    return result && call.ok();
}

bool get_flags_for_uid(
    AIBinder* binder,
    int uid,
    int mask,
    out int flags,
    out AidlCallStatus call) nothrow @nogc
{
    call = AidlCallStatus.init;
    flags = 0;

    AParcel* input;
    if (!prepare(binder, &input, call))
        return false;

    call.payload_status = AParcel_writeInt32(input, uid);
    if (call.payload_status == STATUS_OK)
        call.payload_status = AParcel_writeInt32(input, mask);

    if (call.payload_status != STATUS_OK) {
        delete_if_present(input);
        return false;
    }

    AParcel* output;
    if (!finish(
            binder,
            transaction(ServiceMethodId.get_flags_for_uid),
            &input,
            &output,
            call)) {
        delete_if_present(output);
        return false;
    }

    call.payload_status = AParcel_readInt32(output, &flags);
    delete_if_present(output);
    return call.ok();
}

bool update_flags_for_uid(
    AIBinder* binder,
    int uid,
    int mask,
    int value,
    out AidlCallStatus call) nothrow @nogc
{
    call = AidlCallStatus.init;

    AParcel* input;
    if (!prepare(binder, &input, call))
        return false;

    call.payload_status = AParcel_writeInt32(input, uid);
    if (call.payload_status == STATUS_OK)
        call.payload_status = AParcel_writeInt32(input, mask);
    if (call.payload_status == STATUS_OK)
        call.payload_status = AParcel_writeInt32(input, value);

    if (call.payload_status != STATUS_OK) {
        delete_if_present(input);
        return false;
    }

    AParcel* output;
    const bool result = finish(
        binder,
        transaction(ServiceMethodId.update_flags_for_uid),
        &input,
        &output,
        call
    );
    delete_if_present(output);
    return result && call.ok();
}

bool get_system_property(
    AIBinder* binder,
    const char* name,
    int name_length,
    const char* default_value,
    int default_length,
    ref Utf8Sink result,
    out AidlCallStatus call) nothrow @nogc
{
    call = AidlCallStatus.init;

    AParcel* input;
    if (!prepare(binder, &input, call))
        return false;

    call.payload_status = AParcel_writeString(input, name, name_length);
    if (call.payload_status == STATUS_OK) {
        call.payload_status =
            AParcel_writeString(input, default_value, default_length);
    }

    if (call.payload_status != STATUS_OK) {
        delete_if_present(input);
        return false;
    }

    AParcel* output;
    if (!finish(
            binder,
            transaction(ServiceMethodId.get_system_property),
            &input,
            &output,
            call)) {
        delete_if_present(output);
        return false;
    }

    call.payload_status =
        AParcel_readString(output, &result, &utf8_sink_allocator);
    delete_if_present(output);
    return call.ok();
}

bool set_system_property(
    AIBinder* binder,
    const char* name,
    int name_length,
    const char* value,
    int value_length,
    out AidlCallStatus call) nothrow @nogc
{
    call = AidlCallStatus.init;

    AParcel* input;
    if (!prepare(binder, &input, call))
        return false;

    call.payload_status = AParcel_writeString(input, name, name_length);
    if (call.payload_status == STATUS_OK)
        call.payload_status = AParcel_writeString(input, value, value_length);

    if (call.payload_status != STATUS_OK) {
        delete_if_present(input);
        return false;
    }

    AParcel* output;
    const bool result = finish(
        binder,
        transaction(ServiceMethodId.set_system_property),
        &input,
        &output,
        call
    );
    delete_if_present(output);
    return result && call.ok();
}

bool exit_service(
    AIBinder* binder,
    out AidlCallStatus call) nothrow @nogc
{
    call = AidlCallStatus.init;

    AParcel* input;
    if (!prepare(binder, &input, call))
        return false;

    AParcel* output;
    const bool result = finish(
        binder,
        transaction(ServiceMethodId.exit_),
        &input,
        &output,
        call
    );
    delete_if_present(output);
    return result && call.ok();
}

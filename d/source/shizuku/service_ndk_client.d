module shizuku.service_ndk_client;

import ick.android;
public import shizuku.aidl_ndk :
    AidlCallStatus,
    Utf8Sink,
    Utf8View,
    associate_transaction_class,
    has_transaction_class;
import shizuku.aidl_ndk :
    aidl_finish,
    aidl_prepare,
    define_remote_interface_class,
    delete_parcel,
    utf8_sink_allocator;
import shizuku.api_constants : BINDER_DESCRIPTOR;
import shizuku.service_protocol : ServiceMethodId, transaction;

AIBinder_Class* define_shizuku_service_class() nothrow @nogc
{
    return define_remote_interface_class(BINDER_DESCRIPTOR.ptr);
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
    if (!aidl_prepare(binder, &input, call))
        return false;

    AParcel* output;
    if (!aidl_finish(binder, transaction(method), &input, &output, call)) {
        delete_parcel(output);
        return false;
    }

    call.payload_status = AParcel_readInt32(output, &value);
    delete_parcel(output);
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
    if (!aidl_prepare(binder, &input, call))
        return false;

    AParcel* output;
    if (!aidl_finish(binder, transaction(method), &input, &output, call)) {
        delete_parcel(output);
        return false;
    }

    call.payload_status = AParcel_readBool(output, &value);
    delete_parcel(output);
    return call.ok();
}

/**
 * Legacy Shizuku <= v12 attach transaction.
 *
 * This is transaction 14 from the old interface, not the current explicit
 * attachApplication method id. AIBinder_prepareTransaction supplies the
 * interface token; the payload is application binder + package name.
 */
bool attach_application_v11(
    AIBinder* binder,
    AIBinder* application,
    Utf8View package_name,
    out AidlCallStatus call) nothrow @nogc
{
    call = AidlCallStatus.init;

    if (application is null || !package_name.valid()) {
        call.interface_ok = false;
        return false;
    }

    AParcel* input;
    if (!aidl_prepare(binder, &input, call))
        return false;

    call.payload_status = AParcel_writeStrongBinder(input, application);
    if (call.payload_status == STATUS_OK) {
        call.payload_status = AParcel_writeString(
            input,
            package_name.is_null ? null : package_name.buffer,
            package_name.is_null ? -1 : package_name.length
        );
    }

    if (call.payload_status != STATUS_OK) {
        delete_parcel(input);
        return false;
    }

    AParcel* output;
    const bool result = aidl_finish(
        binder,
        cast(transaction_code_t) 14,
        &input,
        &output,
        call
    );
    delete_parcel(output);
    return result && call.ok();
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
    const(char)* permission,
    int permission_length,
    out int result,
    out AidlCallStatus call) nothrow @nogc
{
    call = AidlCallStatus.init;
    result = 0;

    AParcel* input;
    if (!aidl_prepare(binder, &input, call))
        return false;

    call.payload_status =
        AParcel_writeString(input, permission, permission_length);
    if (call.payload_status != STATUS_OK) {
        delete_parcel(input);
        return false;
    }

    AParcel* output;
    if (!aidl_finish(
            binder,
            transaction(ServiceMethodId.check_permission),
            &input,
            &output,
            call)) {
        delete_parcel(output);
        return false;
    }

    call.payload_status = AParcel_readInt32(output, &result);
    delete_parcel(output);
    return call.ok();
}

bool request_permission(
    AIBinder* binder,
    int request_code,
    out AidlCallStatus call) nothrow @nogc
{
    call = AidlCallStatus.init;

    AParcel* input;
    if (!aidl_prepare(binder, &input, call))
        return false;

    call.payload_status = AParcel_writeInt32(input, request_code);
    if (call.payload_status != STATUS_OK) {
        delete_parcel(input);
        return false;
    }

    AParcel* output;
    const bool result = aidl_finish(
        binder,
        transaction(ServiceMethodId.request_permission),
        &input,
        &output,
        call
    );
    delete_parcel(output);
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
    if (!aidl_prepare(binder, &input, call))
        return false;

    call.payload_status = AParcel_writeInt32(input, uid);
    if (call.payload_status == STATUS_OK)
        call.payload_status = AParcel_writeInt32(input, mask);

    if (call.payload_status != STATUS_OK) {
        delete_parcel(input);
        return false;
    }

    AParcel* output;
    if (!aidl_finish(
            binder,
            transaction(ServiceMethodId.get_flags_for_uid),
            &input,
            &output,
            call)) {
        delete_parcel(output);
        return false;
    }

    call.payload_status = AParcel_readInt32(output, &flags);
    delete_parcel(output);
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
    if (!aidl_prepare(binder, &input, call))
        return false;

    call.payload_status = AParcel_writeInt32(input, uid);
    if (call.payload_status == STATUS_OK)
        call.payload_status = AParcel_writeInt32(input, mask);
    if (call.payload_status == STATUS_OK)
        call.payload_status = AParcel_writeInt32(input, value);

    if (call.payload_status != STATUS_OK) {
        delete_parcel(input);
        return false;
    }

    AParcel* output;
    const bool result = aidl_finish(
        binder,
        transaction(ServiceMethodId.update_flags_for_uid),
        &input,
        &output,
        call
    );
    delete_parcel(output);
    return result && call.ok();
}

bool get_system_property(
    AIBinder* binder,
    const(char)* name,
    int name_length,
    const(char)* default_value,
    int default_length,
    ref Utf8Sink result,
    out AidlCallStatus call) nothrow @nogc
{
    call = AidlCallStatus.init;

    AParcel* input;
    if (!aidl_prepare(binder, &input, call))
        return false;

    call.payload_status = AParcel_writeString(input, name, name_length);
    if (call.payload_status == STATUS_OK) {
        call.payload_status =
            AParcel_writeString(input, default_value, default_length);
    }

    if (call.payload_status != STATUS_OK) {
        delete_parcel(input);
        return false;
    }

    AParcel* output;
    if (!aidl_finish(
            binder,
            transaction(ServiceMethodId.get_system_property),
            &input,
            &output,
            call)) {
        delete_parcel(output);
        return false;
    }

    call.payload_status =
        AParcel_readString(output, &result, &utf8_sink_allocator);
    delete_parcel(output);
    return call.ok();
}

bool set_system_property(
    AIBinder* binder,
    const(char)* name,
    int name_length,
    const(char)* value,
    int value_length,
    out AidlCallStatus call) nothrow @nogc
{
    call = AidlCallStatus.init;

    AParcel* input;
    if (!aidl_prepare(binder, &input, call))
        return false;

    call.payload_status = AParcel_writeString(input, name, name_length);
    if (call.payload_status == STATUS_OK)
        call.payload_status = AParcel_writeString(input, value, value_length);

    if (call.payload_status != STATUS_OK) {
        delete_parcel(input);
        return false;
    }

    AParcel* output;
    const bool result = aidl_finish(
        binder,
        transaction(ServiceMethodId.set_system_property),
        &input,
        &output,
        call
    );
    delete_parcel(output);
    return result && call.ok();
}

bool exit_service(
    AIBinder* binder,
    out AidlCallStatus call) nothrow @nogc
{
    call = AidlCallStatus.init;

    AParcel* input;
    if (!aidl_prepare(binder, &input, call))
        return false;

    AParcel* output;
    const bool result = aidl_finish(
        binder,
        transaction(ServiceMethodId.exit_),
        &input,
        &output,
        call
    );
    delete_parcel(output);
    return result && call.ok();
}

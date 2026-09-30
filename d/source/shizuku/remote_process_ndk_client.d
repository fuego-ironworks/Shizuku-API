module shizuku.remote_process_ndk_client;

import ick.android;
import shizuku.aidl_ndk;
import shizuku.remote_process : RemoteTimeUnit, time_unit_name;
import shizuku.service_protocol : RemoteProcessTransaction;

enum string REMOTE_PROCESS_DESCRIPTOR =
    "moe.shizuku.server.IRemoteProcess";

AIBinder_Class* define_remote_process_class() nothrow @nogc
{
    return define_remote_interface_class(REMOTE_PROCESS_DESCRIPTOR.ptr);
}

bool associate_remote_process_class(
    AIBinder* binder,
    const(AIBinder_Class)* remote_class) nothrow @nogc
{
    return associate_transaction_class(binder, remote_class);
}

private bool finish_remote(
    AIBinder* binder,
    RemoteProcessTransaction method,
    AParcel** input,
    AParcel** output,
    ref AidlCallStatus call) nothrow @nogc
{
    return aidl_finish(
        binder,
        cast(transaction_code_t) method,
        input,
        output,
        call
    );
}

private bool read_fd_no_args(
    AIBinder* binder,
    RemoteProcessTransaction method,
    out int fd,
    out AidlCallStatus call) nothrow @nogc
{
    call = AidlCallStatus.init;
    fd = -1;

    AParcel* input;
    if (!aidl_prepare(binder, &input, call))
        return false;

    AParcel* output;
    if (!finish_remote(binder, method, &input, &output, call)) {
        delete_parcel(output);
        return false;
    }

    call.payload_status = AParcel_readParcelFileDescriptor(output, &fd);
    delete_parcel(output);
    return call.ok();
}

private bool read_int_no_args(
    AIBinder* binder,
    RemoteProcessTransaction method,
    out int value,
    out AidlCallStatus call) nothrow @nogc
{
    call = AidlCallStatus.init;
    value = 0;

    AParcel* input;
    if (!aidl_prepare(binder, &input, call))
        return false;

    AParcel* output;
    if (!finish_remote(binder, method, &input, &output, call)) {
        delete_parcel(output);
        return false;
    }

    call.payload_status = AParcel_readInt32(output, &value);
    delete_parcel(output);
    return call.ok();
}

private bool read_bool_no_args(
    AIBinder* binder,
    RemoteProcessTransaction method,
    out bool value,
    out AidlCallStatus call) nothrow @nogc
{
    call = AidlCallStatus.init;
    value = false;

    AParcel* input;
    if (!aidl_prepare(binder, &input, call))
        return false;

    AParcel* output;
    if (!finish_remote(binder, method, &input, &output, call)) {
        delete_parcel(output);
        return false;
    }

    call.payload_status = AParcel_readBool(output, &value);
    delete_parcel(output);
    return call.ok();
}

/** Returned fd is caller-owned and must be closed. */
bool get_output_stream_fd(
    AIBinder* binder,
    out int fd,
    out AidlCallStatus call) nothrow @nogc
{
    return read_fd_no_args(
        binder,
        RemoteProcessTransaction.get_output_stream,
        fd,
        call
    );
}

/** Returned fd is caller-owned and must be closed. */
bool get_input_stream_fd(
    AIBinder* binder,
    out int fd,
    out AidlCallStatus call) nothrow @nogc
{
    return read_fd_no_args(
        binder,
        RemoteProcessTransaction.get_input_stream,
        fd,
        call
    );
}

/** Returned fd is caller-owned and must be closed. */
bool get_error_stream_fd(
    AIBinder* binder,
    out int fd,
    out AidlCallStatus call) nothrow @nogc
{
    return read_fd_no_args(
        binder,
        RemoteProcessTransaction.get_error_stream,
        fd,
        call
    );
}

bool wait_for(
    AIBinder* binder,
    out int exit_code,
    out AidlCallStatus call) nothrow @nogc
{
    return read_int_no_args(
        binder,
        RemoteProcessTransaction.wait_for,
        exit_code,
        call
    );
}

bool exit_value(
    AIBinder* binder,
    out int exit_code,
    out AidlCallStatus call) nothrow @nogc
{
    return read_int_no_args(
        binder,
        RemoteProcessTransaction.exit_value,
        exit_code,
        call
    );
}

bool destroy(
    AIBinder* binder,
    out AidlCallStatus call) nothrow @nogc
{
    call = AidlCallStatus.init;

    AParcel* input;
    if (!aidl_prepare(binder, &input, call))
        return false;

    AParcel* output;
    const bool result = finish_remote(
        binder,
        RemoteProcessTransaction.destroy,
        &input,
        &output,
        call
    );
    delete_parcel(output);
    return result && call.ok();
}

bool alive(
    AIBinder* binder,
    out bool value,
    out AidlCallStatus call) nothrow @nogc
{
    return read_bool_no_args(
        binder,
        RemoteProcessTransaction.alive,
        value,
        call
    );
}

bool wait_for_timeout(
    AIBinder* binder,
    long timeout,
    RemoteTimeUnit unit,
    out bool completed,
    out AidlCallStatus call) nothrow @nogc
{
    call = AidlCallStatus.init;
    completed = false;

    AParcel* input;
    if (!aidl_prepare(binder, &input, call))
        return false;

    call.payload_status = AParcel_writeInt64(input, timeout);

    const string unit_name = time_unit_name(unit);
    if (call.payload_status == STATUS_OK) {
        call.payload_status = AParcel_writeString(
            input,
            unit_name.ptr,
            cast(int) unit_name.length
        );
    }

    if (call.payload_status != STATUS_OK) {
        delete_parcel(input);
        return false;
    }

    AParcel* output;
    if (!finish_remote(
            binder,
            RemoteProcessTransaction.wait_for_timeout,
            &input,
            &output,
            call)) {
        delete_parcel(output);
        return false;
    }

    call.payload_status = AParcel_readBool(output, &completed);
    delete_parcel(output);
    return call.ok();
}

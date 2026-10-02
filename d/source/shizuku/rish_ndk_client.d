module shizuku.rish_ndk_client;

import ick.android;
import shizuku.aidl_ndk :
    AidlCallStatus,
    Utf8ArrayView,
    Utf8View,
    aidl_finish,
    aidl_prepare,
    define_remote_interface_class,
    delete_parcel,
    utf8_array_element_getter;
import shizuku.rish_config :
    ATTY_ERR,
    TRANSACTION_CREATE_HOST;

/**
 * Rish uses Parcel.writeFileDescriptor/readFileDescriptor, which is the raw
 * Binder FD object encoding. AParcel_writeParcelFileDescriptor is different:
 * it encodes android.os.ParcelFileDescriptor and therefore cannot substitute
 * for the Java call. The narrow raw-FD operation is injected here.
 */
alias RishRawFdWriter =
    extern(C) binder_status_t function(AParcel* parcel, int fd) nothrow @nogc;

struct RishCreateHostPayload {
    ubyte tty;
    int stdin_fd;
    int stdout_fd;
    int stderr_fd;

    Utf8ArrayView args;
    Utf8ArrayView environment;
    Utf8View directory;

    pure nothrow @nogc bool valid() const
    {
        return args.valid()
            && environment.valid()
            && directory.valid();
    }
}

AIBinder_Class* define_rish_interface_class(
    const(char)* descriptor) nothrow @nogc
{
    return define_remote_interface_class(descriptor);
}

private bool write_string_array(
    AParcel* parcel,
    const Utf8ArrayView view,
    ref AidlCallStatus call) nothrow @nogc
{
    call.payload_status = AParcel_writeStringArray(
        parcel,
        view.is_null ? null : cast(const(void)*) &view,
        view.is_null ? -1 : view.length,
        &utf8_array_element_getter
    );
    return call.payload_status == STATUS_OK;
}

/**
 * Encode RishTerminal.createHost's Java Parcel payload.
 *
 * Parcel.writeByte is an int32 on the wire, so AParcel_writeInt32 preserves
 * that field exactly. Raw FD writes are delegated to the explicit bridge.
 */
bool write_create_host_payload(
    AParcel* parcel,
    const RishCreateHostPayload* payload,
    RishRawFdWriter write_raw_fd,
    ref AidlCallStatus call) nothrow @nogc
{
    if (parcel is null || payload is null || write_raw_fd is null
            || !payload.valid()) {
        call.interface_ok = false;
        call.aidl_ok = false;
        return false;
    }

    call.payload_status =
        AParcel_writeInt32(parcel, cast(int) payload.tty);
    if (call.payload_status != STATUS_OK)
        return false;

    call.payload_status = write_raw_fd(parcel, payload.stdin_fd);
    if (call.payload_status != STATUS_OK)
        return false;

    call.payload_status = write_raw_fd(parcel, payload.stdout_fd);
    if (call.payload_status != STATUS_OK)
        return false;

    if ((payload.tty & ATTY_ERR) == 0) {
        call.payload_status = write_raw_fd(parcel, payload.stderr_fd);
        if (call.payload_status != STATUS_OK)
            return false;
    }

    if (!write_string_array(parcel, payload.args, call))
        return false;
    if (!write_string_array(parcel, payload.environment, call))
        return false;

    call.payload_status = AParcel_writeString(
        parcel,
        payload.directory.is_null ? null : payload.directory.buffer,
        payload.directory.is_null ? -1 : payload.directory.length
    );
    return call.payload_status == STATUS_OK;
}

/**
 * Direct libbinder_ndk createHost transaction, except for the one raw-FD
 * operation that the public NDK does not expose.
 */
bool create_host(
    AIBinder* binder,
    int transaction_code_start,
    const RishCreateHostPayload* payload,
    RishRawFdWriter write_raw_fd,
    out AidlCallStatus call) nothrow @nogc
{
    call = AidlCallStatus.init;

    AParcel* input;
    if (!aidl_prepare(binder, &input, call))
        return false;

    if (!write_create_host_payload(
            input,
            payload,
            write_raw_fd,
            call)) {
        delete_parcel(input);
        return false;
    }

    AParcel* output;
    const bool result = aidl_finish(
        binder,
        cast(transaction_code_t)(
            transaction_code_start + TRANSACTION_CREATE_HOST
        ),
        &input,
        &output,
        call
    );
    delete_parcel(output);
    return result && call.ok();
}

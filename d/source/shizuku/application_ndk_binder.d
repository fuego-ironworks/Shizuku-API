module shizuku.application_ndk_binder;

import ick.android;
import shizuku.service_protocol :
    ShizukuApplicationMethodId,
    application_transaction;

enum string SHIZUKU_APPLICATION_DESCRIPTOR =
    "moe.shizuku.server.IShizukuApplication";

alias BindApplicationParcelCallback =
    binder_status_t function(
        void* context,
        const AParcel* bundle_payload
    ) nothrow @nogc;

alias PermissionResultParcelCallback =
    binder_status_t function(
        void* context,
        int request_code,
        const AParcel* bundle_payload
    ) nothrow @nogc;

struct ShizukuApplicationCallbacks {
    void* context;
    BindApplicationParcelCallback bind_application;
    PermissionResultParcelCallback dispatch_permission_result;
}

extern(C) private void* application_on_create(void* args) nothrow @nogc
{
    return args;
}

extern(C) private void application_on_destroy(void* user_data) nothrow @nogc
{
    // Callback storage is caller-owned and must outlive the Binder.
}

extern(C) private binder_status_t application_on_transact(
    AIBinder* binder,
    transaction_code_t code,
    const AParcel* input,
    AParcel* output) nothrow @nogc
{
    if (binder is null || input is null)
        return STATUS_UNKNOWN_TRANSACTION;

    auto callbacks =
        cast(ShizukuApplicationCallbacks*) AIBinder_getUserData(binder);
    if (callbacks is null)
        return STATUS_UNKNOWN_TRANSACTION;

    if (code == application_transaction(
            ShizukuApplicationMethodId.bind_application)) {
        if (callbacks.bind_application is null)
            return STATUS_UNKNOWN_TRANSACTION;

        /*
         * The remaining Parcel begins with the Java Bundle argument. Bundle is
         * deliberately decoded by an Android-framework boundary, not by a
         * private D reimplementation of BaseBundle's wire format.
         */
        return callbacks.bind_application(callbacks.context, input);
    }

    if (code == application_transaction(
            ShizukuApplicationMethodId.dispatch_request_permission_result)) {
        int request_code;
        const binder_status_t status =
            AParcel_readInt32(input, &request_code);
        if (status != STATUS_OK)
            return status;

        if (callbacks.dispatch_permission_result is null)
            return STATUS_UNKNOWN_TRANSACTION;

        return callbacks.dispatch_permission_result(
            callbacks.context,
            request_code,
            input
        );
    }

    /*
     * showPermissionConfirmation is synchronous and Sui-only. A correct
     * implementation must also emit its AIDL status header, so do not fake
     * success until that Sui/framework bridge exists.
     */
    return STATUS_UNKNOWN_TRANSACTION;
}

AIBinder_Class* define_shizuku_application_class() nothrow @nogc
{
    return AIBinder_Class_define(
        SHIZUKU_APPLICATION_DESCRIPTOR.ptr,
        &application_on_create,
        &application_on_destroy,
        &application_on_transact
    );
}

AIBinder* new_shizuku_application_binder(
    const AIBinder_Class* application_class,
    ShizukuApplicationCallbacks* callbacks) nothrow @nogc
{
    if (application_class is null || callbacks is null)
        return null;

    return AIBinder_new(application_class, callbacks);
}

module shizuku.service_connection_ndk_binder;

import ick.android;
import shizuku.service_protocol : ServiceConnectionTransaction;

enum string SERVICE_CONNECTION_DESCRIPTOR =
    "moe.shizuku.server.IShizukuServiceConnection";

alias ConnectedCallback =
    void function(void* context, AIBinder* service) nothrow @nogc;
alias DiedCallback =
    void function(void* context) nothrow @nogc;

struct ServiceConnectionCallbacks {
    void* context;
    ConnectedCallback connected;
    DiedCallback died;
}

extern(C) private void* connection_on_create(void* args) nothrow @nogc
{
    return args;
}

extern(C) private void connection_on_destroy(void* user_data) nothrow @nogc
{
    // Callback storage is caller-owned and must outlive the Binder.
}

extern(C) private binder_status_t connection_on_transact(
    AIBinder* binder,
    transaction_code_t code,
    const AParcel* input,
    AParcel* output) nothrow @nogc
{
    if (binder is null || input is null)
        return STATUS_UNKNOWN_TRANSACTION;

    auto callbacks =
        cast(ServiceConnectionCallbacks*) AIBinder_getUserData(binder);
    if (callbacks is null)
        return STATUS_UNKNOWN_TRANSACTION;

    switch (code) {
    case ServiceConnectionTransaction.connected:
        AIBinder* service = null;
        const binder_status_t status =
            AParcel_readStrongBinder(input, &service);
        if (status != STATUS_OK)
            return status;

        /*
         * The decoded strong reference belongs to this transact handler.
         * The callback receives a borrowed pointer; call AIBinder_incStrong
         * inside the callback before retaining it beyond this invocation.
         */
        if (callbacks.connected !is null)
            callbacks.connected(callbacks.context, service);

        if (service !is null)
            AIBinder_decStrong(service);
        return STATUS_OK;

    case ServiceConnectionTransaction.died:
        if (callbacks.died !is null)
            callbacks.died(callbacks.context);
        return STATUS_OK;

    default:
        return STATUS_UNKNOWN_TRANSACTION;
    }
}

AIBinder_Class* define_service_connection_class() nothrow @nogc
{
    return AIBinder_Class_define(
        SERVICE_CONNECTION_DESCRIPTOR.ptr,
        &connection_on_create,
        &connection_on_destroy,
        &connection_on_transact
    );
}

AIBinder* new_service_connection_binder(
    const AIBinder_Class* connection_class,
    ServiceConnectionCallbacks* callbacks) nothrow @nogc
{
    if (connection_class is null || callbacks is null)
        return null;

    return AIBinder_new(connection_class, callbacks);
}

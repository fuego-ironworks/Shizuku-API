module shizuku.provider_protocol;

enum string METHOD_SEND_BINDER = "sendBinder";
enum string METHOD_GET_BINDER = "getBinder";
enum string ACTION_BINDER_RECEIVED = "moe.shizuku.api.action.BINDER_RECEIVED";
enum string EXTRA_BINDER = "moe.shizuku.privileged.api.intent.extra.BINDER";
enum string PERMISSION = "moe.shizuku.manager.permission.API_V23";
enum string MANAGER_APPLICATION_ID = "moe.shizuku.privileged.api";

enum ProviderInfoResult {
    ok,
    multiprocess_must_be_false,
    exported_must_be_true
}

pure nothrow @nogc ProviderInfoResult validate_provider_info(bool multiprocess, bool exported)
{
    if (multiprocess)
        return ProviderInfoResult.multiprocess_must_be_false;
    if (!exported)
        return ProviderInfoResult.exported_must_be_true;
    return ProviderInfoResult.ok;
}

/** handleSendBinder ignores a new binder while the current binder is alive. */
pure nothrow @nogc bool should_accept_sent_binder(bool current_alive, bool incoming_present)
{
    return !current_alive && incoming_present;
}

/** handleGetBinder replies only for a present, live binder. */
pure nothrow @nogc bool can_reply_with_binder(bool binder_present, bool binder_alive)
{
    return binder_present && binder_alive;
}

struct ProviderState {
    bool enable_multi_process;
    bool is_provider_process;
    bool enable_sui_initialization = true;

    void enable_multi_process_support(bool provider_process) pure nothrow @nogc
    {
        is_provider_process = provider_process;
        enable_multi_process = true;
    }

    void disable_automatic_sui_initialization() pure nothrow @nogc
    {
        enable_sui_initialization = false;
    }
}

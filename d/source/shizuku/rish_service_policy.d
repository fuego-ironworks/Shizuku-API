module shizuku.rish_service_policy;

import shizuku.rish_config :
    ATTY_ERR,
    TRANSACTION_CREATE_HOST,
    TRANSACTION_GET_EXIT_CODE,
    TRANSACTION_SET_WINDOW_SIZE;

enum RishTransaction {
    none,
    create_host,
    set_window_size,
    get_exit_code
}

/**
 * Root preserves environment by default; adb drops it by default.
 * The first exact RISH_PRESERVE_ENV override wins.
 */
pure nothrow @nogc bool preserve_environment(bool is_root, string[] environment)
{
    bool allow = is_root;

    foreach (entry; environment) {
        if (entry == "RISH_PRESERVE_ENV=1")
            return true;
        if (entry == "RISH_PRESERVE_ENV=0")
            return false;
    }
    return allow;
}

pure nothrow @nogc RishTransaction classify_rish_transaction(
    int code,
    int transaction_code_start)
{
    const int relative = code - transaction_code_start;

    if (relative == TRANSACTION_CREATE_HOST)
        return RishTransaction.create_host;
    if (relative == TRANSACTION_SET_WINDOW_SIZE)
        return RishTransaction.set_window_size;
    if (relative == TRANSACTION_GET_EXIT_CODE)
        return RishTransaction.get_exit_code;
    return RishTransaction.none;
}

/**
 * createHost returns handled without decoding the Parcel when reply is null or
 * the transaction is oneway.
 */
pure nothrow @nogc bool create_host_should_decode(bool reply_present, bool oneway)
{
    return reply_present && !oneway;
}

pure nothrow @nogc bool create_host_reads_stderr_descriptor(ubyte tty)
{
    return (tty & ATTY_ERR) == 0;
}

pure nothrow @nogc int missing_host_exit_code()
{
    return -1;
}

module shizuku.user_service;

import shizuku.state : UserServiceArgs;

struct UserServiceAddOptions {
    string component_class;
    bool debuggable;
    int version_code;
    bool daemon;
    bool use_32_bit_app_process;
    string process_name;
    string tag;
    bool has_tag;
    bool no_create;
}

struct UserServiceRemoveOptions {
    string component_class;
    string tag;
    bool has_tag;
    bool remove;
}

/**
 * Java requires a non-null component and a non-null process-name suffix.
 * Empty strings are accepted because Objects.requireNonNull checks null only.
 */
bool build_add_options(
    UserServiceArgs args,
    bool no_create,
    out UserServiceAddOptions options)
{
    if (args.component_class is null || args.process_name is null)
        return false;

    options.component_class = args.component_class;
    options.debuggable = args.debuggable;
    options.version_code = args.version_code;
    options.daemon = args.daemon;
    options.use_32_bit_app_process = args.use_32_bit_app_process;
    options.process_name = args.process_name;
    options.has_tag = args.tag !is null;
    options.tag = args.tag;
    options.no_create = no_create;
    return true;
}

bool build_remove_options(
    UserServiceArgs args,
    bool remove,
    out UserServiceRemoveOptions options)
{
    if (args.component_class is null)
        return false;

    options.component_class = args.component_class;
    options.has_tag = args.tag !is null;
    options.tag = args.tag;
    options.remove = remove;
    return true;
}

/**
 * Newer servers can detach the connection without killing the user service.
 * This is the exact gate in Shizuku.unbindUserService.
 */
pure nothrow @nogc bool supports_connection_detach(int server_version, int patch_version)
{
    return server_version >= 14 || (server_version == 13 && patch_version >= 4);
}

struct UserServiceRecordState {
    int version_code;
    bool daemon;
    bool starting;
    bool binder_present;
    size_t callback_count;

    pure nothrow @nogc bool callback_death_removes_record() const
    {
        return !daemon && callback_count == 0;
    }

    pure nothrow @nogc bool start_timeout_removes_record() const
    {
        return starting;
    }

    void binder_received() pure nothrow @nogc
    {
        starting = false;
        binder_present = true;
    }

    void binder_died() pure nothrow @nogc
    {
        binder_present = false;
    }
}

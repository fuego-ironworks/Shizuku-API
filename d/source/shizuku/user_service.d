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

    /**
     * Exact UserServiceRecord.setBinder behavior: receiving the Binder cancels
     * the scheduled timeout externally but does NOT clear the `starting` flag.
     */
    void binder_received() pure nothrow @nogc
    {
        binder_present = true;
    }

    /**
     * The Java death recipient removes the whole record. This state method
     * clears the local Binder bit and tells the registry to remove it.
     */
    bool binder_died() pure nothrow @nogc
    {
        binder_present = false;
        return true;
    }
}


struct UserServiceDestroyPlan {
    bool unlink_death;
    bool send_destroy_oneway;
    bool kill_callbacks;
}

pure nothrow @nogc UserServiceDestroyPlan destroy_plan(
    bool service_present,
    bool service_alive)
{
    UserServiceDestroyPlan plan;
    plan.unlink_death = service_present;
    plan.send_destroy_oneway = service_present && service_alive;
    plan.kill_callbacks = true;
    return plan;
}

/**
 * Mirrors setStartingTimeout: calling it while already starting is a no-op.
 * On the first call the Java record sets starting=true and schedules a timeout.
 */
pure nothrow @nogc bool begin_starting(ref UserServiceRecordState state)
{
    if (state.starting)
        return false;

    state.starting = true;
    return true;
}

/** The delayed callback removes the record only if starting is still true. */
pure nothrow @nogc bool starting_timeout_should_remove(
    const UserServiceRecordState state)
{
    return state.starting;
}

/**
 * RemoteCallbackList invokes onCallbackDied after dropping the dead callback.
 * The record removes itself only for non-daemon mode with no callbacks left.
 */
pure nothrow @nogc bool callback_died_should_remove(
    bool daemon,
    size_t registered_callbacks_after_death)
{
    return !daemon && registered_callbacks_after_death == 0;
}

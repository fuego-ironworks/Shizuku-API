module shizuku.user_service_manager_policy;

enum ExistingRecordDecision {
    create_new,
    reuse_existing,
    replace_version_mismatch,
    replace_dead
}

/** Java uses tag != null, so an explicitly empty tag remains significant. */
string user_service_key(string package_name, string tag, string class_name)
{
    return package_name ~ ":" ~ (tag !is null ? tag : class_name);
}

/** API < 13.1.4 omitted the flag; omission means remove=true. */
pure nothrow @nogc bool remove_option(bool contains_remove_key, bool encoded_value)
{
    return contains_remove_key ? encoded_value : true;
}

/**
 * Server-side result from addUserService(..., noCreate=true).
 * API 13+ returns the service version; older callers see 0/1.
 */
pure nothrow @nogc int peek_result(
    bool record_exists,
    bool service_alive,
    int record_version,
    int calling_api_version)
{
    if (record_exists && service_alive)
        return calling_api_version >= 13 ? record_version : 0;

    return calling_api_version >= 13 ? -1 : 1;
}

pure nothrow @nogc ExistingRecordDecision existing_record_decision(
    bool record_exists,
    int old_version,
    int requested_version,
    bool starting,
    bool service_present,
    bool service_alive)
{
    if (!record_exists)
        return ExistingRecordDecision.create_new;

    if (old_version != requested_version)
        return ExistingRecordDecision.replace_version_mismatch;

    if (!starting && (!service_present || !service_alive))
        return ExistingRecordDecision.replace_dead;

    return ExistingRecordDecision.reuse_existing;
}

pure nothrow @nogc bool should_start_service(
    bool service_present,
    bool service_alive,
    bool starting)
{
    return !(service_present && service_alive) && !starting;
}

pure nothrow @nogc bool effective_use_32_bit(bool requested, bool device_has_32_bit)
{
    return requested && device_has_32_bit;
}

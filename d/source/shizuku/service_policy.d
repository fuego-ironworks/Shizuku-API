module shizuku.service_policy;

import shizuku.api_constants : SERVER_VERSION;

enum CallingPermissionDecision {
    allow,
    deny_unattached,
    deny_permission
}

enum ManagerPermissionDecision {
    allow,
    deny_not_manager
}

enum PermissionRequestAction {
    ignore,
    reply_allowed,
    reply_denied,
    show_confirmation
}

pure nothrow @nogc ManagerPermissionDecision manager_permission_decision(
    int calling_pid,
    int own_pid,
    bool manager_hook_allows)
{
    if (calling_pid == own_pid || manager_hook_allows)
        return ManagerPermissionDecision.allow;
    return ManagerPermissionDecision.deny_not_manager;
}

/**
 * Mirrors Service.enforceCallingPermission after the subclass hook has run.
 */
pure nothrow @nogc CallingPermissionDecision calling_permission_decision(
    int calling_uid,
    int own_uid,
    bool caller_hook_allows,
    bool client_present,
    bool client_allowed)
{
    if (calling_uid == own_uid || caller_hook_allows)
        return CallingPermissionDecision.allow;

    if (!client_present)
        return CallingPermissionDecision.deny_unattached;

    if (!client_allowed)
        return CallingPermissionDecision.deny_permission;

    return CallingPermissionDecision.allow;
}

pure nothrow @nogc bool self_permission(
    int calling_uid,
    int calling_pid,
    int own_uid,
    int own_pid,
    bool attached_client_allowed)
{
    if (calling_uid == own_uid || calling_pid == own_pid)
        return true;
    return attached_client_allowed;
}

pure nothrow @nogc PermissionRequestAction permission_request_action(
    int calling_uid,
    int calling_pid,
    int own_uid,
    int own_pid,
    bool client_allowed,
    bool config_denied)
{
    if (calling_uid == own_uid || calling_pid == own_pid)
        return PermissionRequestAction.ignore;

    if (client_allowed)
        return PermissionRequestAction.reply_allowed;

    if (config_denied)
        return PermissionRequestAction.reply_denied;

    return PermissionRequestAction.show_confirmation;
}

pure nothrow @nogc bool should_show_rationale(
    int calling_uid,
    int calling_pid,
    int own_uid,
    int own_pid,
    bool config_denied)
{
    if (calling_uid == own_uid || calling_pid == own_pid)
        return true;
    return config_denied;
}

pure nothrow @nogc int effective_calling_api_version(bool client_present, int client_api_version)
{
    return client_present ? client_api_version : SERVER_VERSION;
}

/**
 * Service.transactRemote reads flags from the framed Parcel only for attached
 * API 13+ clients. All other callers use the outer Binder transact flags.
 */
pure nothrow @nogc int remote_target_flags(
    bool client_present,
    int client_api_version,
    int encoded_flags,
    int outer_flags)
{
    return client_present && client_api_version >= 13 ? encoded_flags : outer_flags;
}

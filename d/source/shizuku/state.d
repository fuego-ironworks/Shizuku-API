module shizuku.state;

import shizuku.api_constants : SERVER_VERSION;

enum int PERMISSION_GRANTED = 0;
enum int PERMISSION_DENIED = -1;

struct ServerState {
    int uid = -1;
    int api_version = -1;
    int patch_version = -1;
    string security_context;
    bool permission_granted;
    bool should_show_permission_rationale;
    bool pre_v11;
    bool binder_ready;

    /**
     * Full local reset. This is stronger than Shizuku.java's binder-death path.
     * Use binder_lost() when translating onBinderReceived(null, ...).
     */
    void reset()
    {
        uid = -1;
        api_version = -1;
        patch_version = -1;
        security_context = null;
        permission_granted = false;
        should_show_permission_rationale = false;
        pre_v11 = false;
        binder_ready = false;
    }

    /**
     * Exact state cleared by Shizuku.onBinderReceived(null, null).
     * Upstream intentionally does not clear patch_version, permission state,
     * rationale state, or pre_v11 here.
     */
    void binder_lost()
    {
        uid = -1;
        api_version = -1;
        security_context = null;
        binder_ready = false;
    }

    void bind_application(
        int new_uid,
        int new_api_version,
        int new_patch_version,
        string new_security_context,
        bool granted,
        bool show_rationale)
    {
        uid = new_uid;
        api_version = new_api_version;
        patch_version = new_patch_version;
        security_context = new_security_context;
        permission_granted = granted;
        should_show_permission_rationale = show_rationale;
        binder_ready = true;
    }

    int permission_result() const pure nothrow @nogc
    {
        return permission_granted ? PERMISSION_GRANTED : PERMISSION_DENIED;
    }
}

struct UserServiceArgs {
    string component_class;
    int version_code = 1;
    string process_name;
    string tag;
    bool debuggable;
    bool daemon = true;
    bool use_32_bit_app_process;

    /**
     * Java checks tag != null, not tag.length != 0. An explicitly empty tag is
     * therefore a real cache key and must not fall back to component_class.
     */
    string connection_key() const pure nothrow @nogc
    {
        return tag !is null ? tag : component_class;
    }
}

pure nothrow @nogc int permission_result(bool allowed)
{
    return allowed ? PERMISSION_GRANTED : PERMISSION_DENIED;
}

pure nothrow @nogc int peek_user_service_result(
    bool pre_v11,
    int server_version,
    int add_user_service_result)
{
    if (!pre_v11 && server_version >= SERVER_VERSION)
        return add_user_service_result;

    return add_user_service_result == 0 ? 0 : -1;
}

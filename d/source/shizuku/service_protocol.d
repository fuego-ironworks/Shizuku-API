module shizuku.service_protocol;

import ick.android.types : transaction_code_t;
import shizuku.api_constants : BINDER_TRANSACTION_transact;

/** Explicit method ids from IShizukuService.aidl. */
enum ServiceMethodId : uint {
    get_version = 2,
    get_uid = 3,
    check_permission = 4,
    new_process = 7,
    get_selinux_context = 8,
    get_system_property = 9,
    set_system_property = 10,
    add_user_service = 11,
    remove_user_service = 12,
    request_permission = 14,
    check_self_permission = 15,
    should_show_request_permission_rationale = 16,
    attach_application = 17,
    exit_ = 100,
    attach_user_service = 101,
    dispatch_package_changed = 102,
    is_hidden = 103,
    dispatch_permission_confirmation_result = 104,
    get_flags_for_uid = 105,
    update_flags_for_uid = 106
}

/**
 * AIDL explicit method ids are offsets from FIRST_CALL_TRANSACTION (1).
 * The current Java client confirms attach_application id 17 -> transaction 18.
 */
pure nothrow @nogc transaction_code_t transaction(ServiceMethodId method)
{
    return cast(transaction_code_t)(cast(uint) method + 1u);
}

enum transaction_code_t TRANSACTION_REMOTE = BINDER_TRANSACTION_transact;
enum transaction_code_t TRANSACTION_ATTACH_APPLICATION_V13 = 18;
enum transaction_code_t TRANSACTION_ATTACH_APPLICATION_V11 = 14;

static assert(transaction(ServiceMethodId.attach_application) == TRANSACTION_ATTACH_APPLICATION_V13);
static assert(transaction(ServiceMethodId.add_user_service) == 12);
static assert(transaction(ServiceMethodId.remove_user_service) == 13);

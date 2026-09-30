module shizuku.rish_entry;

enum RishStartAction {
    request_permission,
    start_terminal
}

/** Rish.startShell(args, permissionGranted) control flow. */
pure nothrow @nogc RishStartAction next_start_action(bool permission_granted)
{
    return permission_granted
        ? RishStartAction.start_terminal
        : RishStartAction.request_permission;
}

/** Any exception in terminal construction/start/wait maps to process exit 1. */
pure nothrow @nogc int terminal_failure_exit_code()
{
    return 1;
}

module shizuku.rish_host_policy;

import shizuku.rish_config : ATTY_IN, ATTY_OUT, ATTY_ERR;

enum int RISH_INITIAL_EXIT_CODE = int.max;

ubyte[] c_bytes_for_string(string value)
{
    if (value is null)
        return null;

    auto result = new ubyte[value.length + 1];
    foreach (i, c; value)
        result[i] = cast(ubyte) c;
    result[$ - 1] = 0;
    return result;
}

bool c_bytes_for_string_array(string[] values, out ubyte[] result)
{
    result = null;
    if (values is null)
        return true;

    size_t length = values.length;
    foreach (value; values) {
        // Java String.getBytes() throws for a null array element.
        if (value is null)
            return false;
        length += value.length;
    }

    result = new ubyte[length];
    size_t offset;

    foreach (value; values) {
        foreach (c; value)
            result[offset++] = cast(ubyte) c;
        ++offset; // zero-filled NUL
    }
    return true;
}

struct RishTtyPlan {
    bool in_tty;
    bool out_tty;
    bool err_tty;

    pure nothrow @nogc bool needs_ptmx() const
    {
        return in_tty || out_tty || err_tty;
    }

    pure nothrow @nogc bool needs_stdin_pipe() const
    {
        return !in_tty;
    }

    pure nothrow @nogc bool needs_stdout_pipe() const
    {
        return !out_tty;
    }

    pure nothrow @nogc bool needs_stderr_pipe() const
    {
        return !err_tty;
    }
}

pure nothrow @nogc RishTtyPlan tty_plan(ubyte tty)
{
    RishTtyPlan result;
    result.in_tty = (tty & ATTY_IN) != 0;
    result.out_tty = (tty & ATTY_OUT) != 0;
    result.err_tty = (tty & ATTY_ERR) != 0;
    return result;
}

/** Child argv always prepends /system/bin/sh before the supplied argument block. */
string[] shell_argv(string[] args)
{
    string[] result;
    result ~= "/system/bin/sh";
    result ~= args;
    return result;
}

/**
 * Native code uses execvpe only when envc > 0. Null and an explicitly empty
 * environment both therefore inherit the parent environment via execvp.
 */
pure nothrow @nogc bool use_explicit_environment(int env_count)
{
    return env_count > 0;
}

/** RishHost_waitFor returns 0 when the child was terminated by a signal. */
pure nothrow @nogc int wait_result(bool exited, int exit_status, bool signaled)
{
    if (exited)
        return exit_status;
    if (signaled)
        return 0;
    return -1;
}

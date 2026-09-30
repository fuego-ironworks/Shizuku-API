module shizuku.rish_terminal_policy;

import shizuku.rish_config : ATTY_IN, ATTY_OUT, ATTY_ERR;

enum ubyte ATTY_ALL = cast(ubyte)(ATTY_IN | ATTY_OUT | ATTY_ERR);

pure nothrow @nogc ubyte detect_tty(bool stdin_tty, bool stdout_tty, bool stderr_tty)
{
    ubyte tty;
    if (stdin_tty)
        tty |= ATTY_IN;
    if (stdout_tty)
        tty |= ATTY_OUT;
    if (stderr_tty)
        tty |= ATTY_ERR;
    return tty;
}

/**
 * Native RishTerminal picks the first terminal fd in stdin, stdout, stderr
 * order, or -1 if none is a tty.
 */
pure nothrow @nogc int selected_tty_fd(
    ubyte tty,
    int stdin_fd = 0,
    int stdout_fd = 1,
    int stderr_fd = 2)
{
    if ((tty & ATTY_IN) != 0)
        return stdin_fd;
    if ((tty & ATTY_OUT) != 0)
        return stdout_fd;
    if ((tty & ATTY_ERR) != 0)
        return stderr_fd;
    return -1;
}

pure nothrow @nogc bool makes_terminal_raw(ubyte tty)
{
    return tty == ATTY_ALL;
}

pure nothrow @nogc bool blocks_sigwinch(ubyte tty)
{
    return (tty & ATTY_OUT) != 0;
}

pure nothrow @nogc bool needs_client_stderr_pipe(ubyte tty)
{
    return (tty & ATTY_ERR) == 0;
}

/**
 * Fidelity note for RishTerminal.java at SOURCE.lock: start() passes stdout[0]
 * as both stdout_pipe and stderr_pipe. The separately created stderr[0] is not
 * passed to native start. Keep this explicit until upstream intent is verified.
 */
struct TerminalNativeFds {
    int stdin_fd;
    int stdout_fd;
    int stderr_fd;
}

pure nothrow @nogc TerminalNativeFds upstream_terminal_native_fds(
    int stdin_write_fd,
    int stdout_read_fd,
    int stderr_read_fd)
{
    TerminalNativeFds result;
    result.stdin_fd = stdin_write_fd;
    result.stdout_fd = stdout_read_fd;
    result.stderr_fd = stdout_read_fd;
    return result;
}

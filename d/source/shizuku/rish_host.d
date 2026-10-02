module shizuku.rish_host;

import shizuku.rish_host_policy :
    RISH_INITIAL_EXIT_CODE,
    c_bytes_for_string,
    c_bytes_for_string_array;

/**
 * Arguments handed to the native RishHost.start implementation.
 *
 * ParcelFileDescriptor.detachFd is an Android framework boundary; the D side
 * receives already-detached integer descriptors and preserves their ownership
 * transfer exactly.
 */
struct RishHostStartInput {
    ubyte[] arg_block;
    int argc;

    ubyte[] env_block;
    int envc;

    ubyte[] dir_block;
    ubyte tty;

    int stdin_fd;
    int stdout_fd;
    int stderr_fd;
}

/**
 * Framework-free translation of the Java RishHost object.
 *
 * Fork/pty/transfer and waitpid stay in the Bionic boundary. This object owns
 * the Java-visible state and marshals the exact blocks passed to that boundary.
 */
final class RishHostState {
    string[] args;
    string[] environment;
    string directory;
    ubyte tty;

    int stdin_fd;
    int stdout_fd;
    int stderr_fd;

    int pid;
    int ptmx = -1;
    int exit_code = RISH_INITIAL_EXIT_CODE;

    this(
        string[] args,
        string[] environment,
        string directory,
        ubyte tty,
        int stdin_fd,
        int stdout_fd,
        int stderr_fd)
    {
        this.args = args;
        this.environment = environment;
        this.directory = directory;
        this.tty = tty;
        this.stdin_fd = stdin_fd;
        this.stdout_fd = stdout_fd;
        this.stderr_fd = stderr_fd;
    }

    /**
     * Mirrors RishHost.start up to the JNI call.
     *
     * Java dereferences args.length after building argBlock, so a null argv is
     * a failure rather than an empty argument list. Null env remains envc=-1;
     * an explicitly empty env remains envc=0.
     */
    bool prepare_start(out RishHostStartInput input)
    {
        input = RishHostStartInput.init;

        if (args is null)
            return false;
        if (!c_bytes_for_string_array(args, input.arg_block))
            return false;
        if (!c_bytes_for_string_array(environment, input.env_block))
            return false;

        input.dir_block = c_bytes_for_string(directory);
        input.argc = cast(int) args.length;
        input.envc = environment is null
            ? -1
            : cast(int) environment.length;
        input.tty = tty;
        input.stdin_fd = stdin_fd;
        input.stdout_fd = stdout_fd;
        input.stderr_fd = stderr_fd;
        return true;
    }

    /** Apply the two integers returned by native start(): pid and ptmx. */
    void started(int child_pid, int ptmx_fd) pure nothrow @nogc
    {
        pid = child_pid;
        ptmx = ptmx_fd;
    }

    /** Native setWindowSize targets the ptmx retained from start(). */
    int window_size_fd() const pure nothrow @nogc
    {
        return ptmx;
    }

    /**
     * Java updates exitCode from its background wait thread. Thread creation is
     * a runtime boundary; the resulting state transition belongs here.
     */
    void completed(int code) pure nothrow @nogc
    {
        exit_code = code;
    }
}

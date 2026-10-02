module shizuku.rish_host_native;

import ick.android.bionic :
    O_RDWR,
    PATH_MAX,
    SIGKILL,
    STDERR_FILENO,
    STDIN_FILENO,
    STDOUT_FILENO,
    X_OK,
    access,
    chdir,
    close,
    dup2,
    execvp,
    execvpe,
    exit,
    fork,
    free,
    isatty,
    kill,
    malloc,
    open,
    pipe2,
    ptsname_r,
    setsid;
import shizuku.rish_bionic :
    open_ptmx,
    transfer_async;
import shizuku.rish_host :
    RishHostStartInput;
import shizuku.rish_host_policy :
    tty_plan,
    use_explicit_environment;

private enum string SHELL_PATH = "/system/bin/sh\0";

struct RishNativeStartResult {
    int pid = -1;
    int ptmx = -1;
    bool ok;
}

private char** make_vector(
    ubyte[] block,
    int count,
    bool prepend_shell) nothrow @nogc
{
    if (count < 0)
        return null;

    const size_t prefix = prepend_shell ? 1 : 0;
    const size_t entries = cast(size_t) count + prefix + 1;
    auto vector = cast(char**) malloc(entries * void*.sizeof);
    if (vector is null)
        return null;

    size_t output;
    if (prepend_shell)
        vector[output++] = cast(char*) SHELL_PATH.ptr;

    auto p = cast(char*) block.ptr;
    foreach (_; 0 .. count) {
        vector[output++] = p;
        while (*p != 0)
            ++p;
        ++p;
    }
    vector[output] = null;
    return vector;
}

private struct KillContext {
    int pid;
}

extern(C) private void kill_child_on_output_close(
    void* raw) nothrow @nogc
{
    auto context = cast(KillContext*) raw;
    if (context is null)
        return;

    kill(context.pid, SIGKILL);
    free(context);
}

private void start_parent_transfers(
    const ref RishHostStartInput input,
    int pid,
    int ptmx,
    int[2] stdin_pipe,
    int[2] stdout_pipe,
    int[2] stderr_pipe) nothrow @nogc
{
    const plan = tty_plan(input.tty);

    if (plan.in_tty) {
        transfer_async(input.stdin_fd, ptmx);
    } else {
        transfer_async(input.stdin_fd, stdin_pipe[1]);
        close(stdin_pipe[0]);
    }

    auto kill_context = cast(KillContext*) malloc(KillContext.sizeof);
    if (kill_context !is null)
        kill_context.pid = pid;

    bool output_started;
    if (plan.out_tty) {
        output_started = transfer_async(
            ptmx,
            input.stdout_fd,
            kill_context is null ? null : &kill_child_on_output_close,
            kill_context
        );
    } else {
        output_started = transfer_async(
            stdout_pipe[0],
            input.stdout_fd,
            kill_context is null ? null : &kill_child_on_output_close,
            kill_context
        );
        close(stdout_pipe[1]);
    }

    if (!output_started && kill_context !is null)
        free(kill_context);

    if (!plan.err_tty) {
        transfer_async(stderr_pipe[0], input.stderr_fd);
        close(stderr_pipe[1]);
    }
}

private void run_child(
    const ref RishHostStartInput input,
    int ptmx,
    int[2] stdin_pipe,
    int[2] stdout_pipe,
    int[2] stderr_pipe,
    char** argv,
    char** envv) nothrow @nogc
{
    const plan = tty_plan(input.tty);

    if (setsid() < 0)
        exit(1);

    if (input.dir_block !is null) {
        auto directory = cast(const(char)*) input.dir_block.ptr;
        if (access(directory, X_OK) == 0)
            chdir(directory);
    }

    int pts = -1;
    if (plan.needs_ptmx()) {
        char[PATH_MAX] pts_slave;
        if (ptsname_r(ptmx, pts_slave.ptr, pts_slave.length) == -1)
            exit(1);

        pts = open(pts_slave.ptr, O_RDWR);
    }

    if (plan.in_tty) {
        dup2(pts, STDIN_FILENO);
    } else {
        dup2(stdin_pipe[0], STDIN_FILENO);
        close(stdin_pipe[1]);
    }

    if (plan.out_tty) {
        dup2(pts, STDOUT_FILENO);
    } else {
        dup2(stdout_pipe[1], STDOUT_FILENO);
        close(stdout_pipe[0]);
    }

    if (plan.err_tty) {
        dup2(pts, STDERR_FILENO);
    } else {
        dup2(stderr_pipe[1], STDERR_FILENO);
        close(stderr_pipe[0]);
    }

    // Preserve upstream's diagnostic-only isatty calls without depending on
    // Android logging here.
    isatty(STDIN_FILENO);
    isatty(STDOUT_FILENO);
    isatty(STDERR_FILENO);

    if (pts != -1)
        close(pts);

    if (use_explicit_environment(input.envc))
        execvpe(SHELL_PATH.ptr, argv, envv);
    else
        execvp(SHELL_PATH.ptr, argv);

    exit(1);
}

/**
 * Direct D translation of rikka_rish_RishHost.cpp::RishHost_startHost after
 * JNI byte-array extraction.
 *
 * The input owns already-packed argv/env/dir blocks. On success the parent
 * returns the same pid/ptmx pair as JNI; the child replaces itself with
 * /system/bin/sh.
 */
RishNativeStartResult start_host(
    const ref RishHostStartInput input) nothrow @nogc
{
    RishNativeStartResult result;

    if (input.argc < 0)
        return result;

    char** argv = make_vector(input.arg_block, input.argc, true);
    if (argv is null)
        return result;

    char** envv;
    if (use_explicit_environment(input.envc)) {
        envv = make_vector(input.env_block, input.envc, false);
        if (envv is null) {
            free(argv);
            return result;
        }
    }

    const plan = tty_plan(input.tty);

    int ptmx = -1;
    if (plan.needs_ptmx()) {
        ptmx = open_ptmx();
        if (ptmx == -1) {
            free(argv);
            if (envv !is null)
                free(envv);
            return result;
        }
    }

    int[2] stdin_pipe = [-1, -1];
    int[2] stdout_pipe = [-1, -1];
    int[2] stderr_pipe = [-1, -1];

    if (plan.needs_stdin_pipe())
        pipe2(stdin_pipe.ptr, 0);
    if (plan.needs_stdout_pipe())
        pipe2(stdout_pipe.ptr, 0);
    if (plan.needs_stderr_pipe())
        pipe2(stderr_pipe.ptr, 0);

    const int pid = fork();
    if (pid == -1) {
        free(argv);
        if (envv !is null)
            free(envv);
        return result;
    }

    if (pid > 0) {
        start_parent_transfers(
            input,
            pid,
            ptmx,
            stdin_pipe,
            stdout_pipe,
            stderr_pipe
        );

        free(argv);
        if (envv !is null)
            free(envv);

        result.pid = pid;
        result.ptmx = ptmx;
        result.ok = true;
        return result;
    }

    run_child(
        input,
        ptmx,
        stdin_pipe,
        stdout_pipe,
        stderr_pipe,
        argv,
        envv
    );

    return result;
}

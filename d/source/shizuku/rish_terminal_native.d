module shizuku.rish_terminal_native;

import ick.android.bionic :
    BionicPthreadMutex,
    BionicTermios,
    SIG_BLOCK,
    SIGWINCH,
    STDERR_FILENO,
    STDIN_FILENO,
    STDOUT_FILENO,
    isatty,
    pthread_mutex_init,
    pthread_mutex_lock,
    pthread_mutex_unlock,
    pthread_sigmask,
    sigaddset,
    sigemptyset,
    signal,
    sigset_t;
import shizuku.rish_bionic :
    get_window_size,
    make_tty_raw,
    restore_fd,
    transfer_async;
import shizuku.rish_config :
    ATTY_ERR;
import shizuku.rish_terminal_policy :
    blocks_sigwinch,
    detect_tty,
    makes_terminal_raw,
    selected_tty_fd;

private __gshared BionicPthreadMutex process_mutex;
private __gshared BionicPthreadMutex winch_mutex;
private __gshared BionicTermios old_terminal;
private __gshared int tty_in_raw;
private __gshared int active_tty_fd = -1;

/** JNI_OnLoad's RishTerminal native-state initialization. */
void initialize_terminal_native() nothrow @nogc
{
    pthread_mutex_init(&process_mutex, null);
    pthread_mutex_init(&winch_mutex, null);
}

extern(C) private void remote_exit(void* ignored) nothrow @nogc
{
    if (tty_in_raw != 0) {
        if (restore_fd(active_tty_fd, old_terminal) == 0)
            tty_in_raw = 0;
    }

    pthread_mutex_unlock(&process_mutex);
}

extern(C) private void sigwinch_handler(int signal_number) nothrow @nogc
{
    pthread_mutex_unlock(&winch_mutex);
}

/**
 * RishTerminal_prepare: detect tty bits and block SIGWINCH on the calling
 * thread when stdout is a tty.
 */
ubyte prepare_terminal() nothrow @nogc
{
    const ubyte tty = detect_tty(
        isatty(STDIN_FILENO) != 0,
        isatty(STDOUT_FILENO) != 0,
        isatty(STDERR_FILENO) != 0
    );

    if (blocks_sigwinch(tty)) {
        sigset_t winch;
        sigemptyset(&winch);
        sigaddset(&winch, SIGWINCH);
        pthread_sigmask(SIG_BLOCK, &winch, null);
    }

    return tty;
}

/**
 * RishTerminal_start after Java has detached the three pipe descriptors.
 *
 * This deliberately preserves upstream's mutex-as-event behavior and
 * SIGWINCH handler, including unlocking those mutexes from a different
 * execution context.
 */
int start_terminal(
    ubyte tty,
    int stdin_pipe,
    int stdout_pipe,
    int stderr_pipe) nothrow @nogc
{
    const int tty_fd = selected_tty_fd(
        tty,
        STDIN_FILENO,
        STDOUT_FILENO,
        STDERR_FILENO
    );
    active_tty_fd = tty_fd;

    if (makes_terminal_raw(tty)) {
        if (make_tty_raw(tty_fd, old_terminal) == 0)
            tty_in_raw = 1;
    }

    pthread_mutex_lock(&process_mutex);

    transfer_async(STDIN_FILENO, stdin_pipe);
    transfer_async(stdout_pipe, STDOUT_FILENO, &remote_exit);

    if ((tty & ATTY_ERR) == 0)
        transfer_async(stderr_pipe, STDERR_FILENO);

    signal(SIGWINCH, &sigwinch_handler);
    return tty_fd;
}

/** RishTerminal_waitForWindowSizeChange. */
long wait_for_window_size_change(int fd) nothrow @nogc
{
    pthread_mutex_lock(&winch_mutex);
    return get_window_size(fd);
}

/** RishTerminal_waitForProcessExit. */
void wait_for_process_exit() nothrow @nogc
{
    pthread_mutex_lock(&process_mutex);
    pthread_mutex_unlock(&process_mutex);
}

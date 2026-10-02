module shizuku.rish_bionic;

import ick.android.bionic :
    BionicTermios,
    BionicWinSize,
    ECHILD,
    EINTR,
    O_RDWR,
    TCSANOW,
    TIOCGWINSZ,
    TIOCSWINSZ,
    bionic_errno,
    cfmakeraw,
    close,
    grantpt,
    ioctl,
    open,
    read,
    ssize_t,
    tcgetattr,
    tcsetattr,
    unlockpt,
    waitpid,
    wifexited,
    wifsignaled,
    wexitstatus,
    write;

alias TransferFinished =
    extern(C) void function(void* context) nothrow @nogc;

private immutable char[] PTMX_PATH = "/dev/ptmx\0";

union PackedWindowSize {
    long packed;
    BionicWinSize window;
}

static assert(PackedWindowSize.sizeof == long.sizeof);

/** Native pts.cpp::make_tty_raw without the Android logging side effect. */
int make_tty_raw(
    int fd,
    out BionicTermios old_termios) nothrow @nogc
{
    BionicTermios current;
    if (tcgetattr(fd, &current) < 0)
        return -1;

    old_termios = current;
    cfmakeraw(&current);

    if (tcsetattr(fd, TCSANOW, &current) < 0)
        return -1;
    return 0;
}

/** Native pts.cpp::restore_fd without logging. */
int restore_fd(
    int fd,
    const ref BionicTermios old_termios) nothrow @nogc
{
    return tcsetattr(fd, TCSANOW, &old_termios) < 0 ? -1 : 0;
}

private int write_full(
    int fd,
    const(void)* initial_buffer,
    size_t initial_count) nothrow @nogc
{
    auto buffer = cast(const(ubyte)*) initial_buffer;
    size_t count = initial_count;

    while (count > 0) {
        const size_t maximum = cast(size_t) ssize_t.max;
        const size_t chunk = count < maximum ? count : maximum;
        const ssize_t amount = write(fd, buffer, chunk);

        if (amount <= 0) {
            if (amount < 0 && bionic_errno() == EINTR)
                continue;
            return -1;
        }

        buffer += cast(size_t) amount;
        count -= cast(size_t) amount;
    }

    return 0;
}

/**
 * Synchronous half of pts.cpp::transfer.
 *
 * Thread creation lives one layer up; this preserves the byte loop, EINTR
 * retry, close ownership, and completion callback ordering.
 */
void transfer(
    int input_fd,
    int output_fd,
    bool close_input,
    bool close_output,
    TransferFinished finished = null,
    void* context = null) nothrow @nogc
{
    ubyte[8192] buffer;

    while (true) {
        ssize_t length;
        do {
            length = read(input_fd, buffer.ptr, buffer.length);
        } while (length < 0 && bionic_errno() == EINTR);

        if (length <= 0)
            break;
        if (write_full(output_fd, buffer.ptr, cast(size_t) length) == -1)
            break;
    }

    if (close_input)
        close(input_fd);
    if (close_output)
        close(output_fd);
    if (finished !is null)
        finished(context);
}

/** Native pts.cpp::open_ptmx. */
int open_ptmx() nothrow @nogc
{
    const int fd = open(PTMX_PATH.ptr, O_RDWR);
    if (fd == -1)
        return -1;

    if (grantpt(fd) == -1) {
        close(fd);
        return -1;
    }

    if (unlockpt(fd) == -1) {
        close(fd);
        return -1;
    }

    return fd;
}

/** Native RishTerminal_getWindowSize wire representation. */
long get_window_size(int fd) nothrow @nogc
{
    PackedWindowSize bits;
    bits.packed = 0;

    if (ioctl(fd, TIOCGWINSZ, &bits.window) == -1)
        return 0;
    return bits.packed;
}

/** Native RishHost_setWindowSize wire representation. */
int set_window_size(int ptmx, long packed) nothrow @nogc
{
    PackedWindowSize bits;
    bits.packed = packed;

    return ioctl(ptmx, TIOCSWINSZ, &bits.window) == -1 ? -1 : 0;
}

/** Native RishHost_waitFor, including TEMP_FAILURE_RETRY(waitpid). */
int wait_for_child(int pid) nothrow @nogc
{
    if (pid < 0)
        return -1;

    int status;
    while (true) {
        const int waited = waitpid(pid, &status, 0);
        if (waited == -1) {
            const int error = bionic_errno();
            if (error == EINTR)
                continue;
            if (error == ECHILD)
                return 0;
            return -1;
        }

        if (wifexited(status))
            return wexitstatus(status);
        if (wifsignaled(status))
            return 0;
    }
}

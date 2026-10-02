module shizuku.rish_service;

import shizuku.rish_host : RishHostState;
import shizuku.rish_service_policy :
    missing_host_exit_code,
    preserve_environment;

private struct CallingHost {
    int calling_pid;
    RishHostState host;
}

/**
 * Translation of RishService's static HOSTS map and create/lookup semantics.
 *
 * Binder.getCallingPid, permission enforcement, Parcel decoding, the native
 * host start, and the actual setWindowSize call remain explicit boundaries.
 * One RishServiceState instance represents the Java class' process-wide map.
 */
final class RishServiceState {
    private CallingHost[] hosts;

    /**
     * Build the host exactly as createHost does before host.start().
     *
     * The caller must run the native start first and call commit_started_host
     * only after it succeeds. Java inserts into HOSTS after host.start().
     */
    RishHostState prepare_create_host(
        bool is_root,
        string[] args,
        string[] environment,
        string directory,
        ubyte tty,
        int stdin_fd,
        int stdout_fd,
        int stderr_fd)
    {
        string[] effective_environment = environment;
        if (!preserve_environment(is_root, environment))
            effective_environment = null;

        return new RishHostState(
            args,
            effective_environment,
            directory,
            tty,
            stdin_fd,
            stdout_fd,
            stderr_fd
        );
    }

    /**
     * HashMap.put(callingPid, host): a second host from the same caller replaces
     * the table entry without stopping or otherwise mutating the old host.
     */
    bool commit_started_host(int calling_pid, RishHostState host)
    {
        if (host is null)
            return false;

        foreach (ref entry; hosts) {
            if (entry.calling_pid == calling_pid) {
                entry.host = host;
                return true;
            }
        }

        CallingHost entry;
        entry.calling_pid = calling_pid;
        entry.host = host;
        hosts ~= entry;
        return true;
    }

    RishHostState host_for(int calling_pid)
    {
        foreach (entry; hosts) {
            if (entry.calling_pid == calling_pid)
                return entry.host;
        }
        return null;
    }

    /**
     * RishService.setWindowSize is a no-op for a missing caller host. The
     * Binder adapter can call window_size_fd() on the returned host.
     */
    RishHostState window_size_host(int calling_pid)
    {
        return host_for(calling_pid);
    }

    int exit_code_for(int calling_pid)
    {
        auto host = host_for(calling_pid);
        return host is null
            ? missing_host_exit_code()
            : host.exit_code;
    }

    size_t host_count() const pure nothrow @nogc
    {
        return hosts.length;
    }
}

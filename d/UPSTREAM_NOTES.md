# Pinned-upstream fidelity notes

These are observations about the exact Shizuku-API source pinned in SOURCE.lock.
They are not silently corrected in the D translation because the first job is
behavioral fidelity.

## RishTerminal stderr fd

`RishTerminal.createHost()` creates a distinct stderr pipe and sends its write
end to the remote host when stderr is not a tty. Later, `RishTerminal.start()`
calls the native method as:

```
start(tty, getFd(stdin, 1), getFd(stdout, 0), getFd(stdout, 0))
```

The native stderr argument therefore receives the stdout read fd, while the
created stderr read fd is not passed to native `RishTerminal_start`.

The D policy translation records this exact mapping as
`upstream_terminal_native_fds`. Before making the D implementation runnable,
verify whether this is intentional compatibility behavior or an upstream bug.

## RishTerminal reply Parcel mismatch

Both `setWindowSize()` and `requestExitCode()` allocate a reply Parcel but
pass `null` as the reply argument to `IBinder.transact`.

They then call `reply.readException()`; `requestExitCode()` additionally
calls `reply.readInt()`. On the server, `RishService` only writes the exit
code when its reply Parcel is non-null.

This is internally inconsistent on the pinned source. Do not normalize it
silently in D. Verify on-device/upstream behavior, then either preserve a
required Binder quirk or fix it with a regression test.

## Environment inheritance

Native RishHost selects `execvpe` only when `envc > 0`. Both a null
environment (`envc == -1`) and an explicitly empty environment
(`envc == 0`) use `execvp` and inherit the process environment. The D port
preserves this distinction.

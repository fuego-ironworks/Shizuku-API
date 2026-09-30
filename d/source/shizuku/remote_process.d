module shizuku.remote_process;

enum RemoteTimeUnit {
    nanoseconds,
    microseconds,
    milliseconds,
    seconds,
    minutes,
    hours,
    days
}

pure nothrow @nogc bool parse_time_unit(string name, out RemoteTimeUnit unit)
{
    switch (name) {
    case "NANOSECONDS":
        unit = RemoteTimeUnit.nanoseconds;
        return true;
    case "MICROSECONDS":
        unit = RemoteTimeUnit.microseconds;
        return true;
    case "MILLISECONDS":
        unit = RemoteTimeUnit.milliseconds;
        return true;
    case "SECONDS":
        unit = RemoteTimeUnit.seconds;
        return true;
    case "MINUTES":
        unit = RemoteTimeUnit.minutes;
        return true;
    case "HOURS":
        unit = RemoteTimeUnit.hours;
        return true;
    case "DAYS":
        unit = RemoteTimeUnit.days;
        return true;
    default:
        unit = RemoteTimeUnit.nanoseconds;
        return false;
    }
}

pure nothrow @nogc long nanos_per_unit(RemoteTimeUnit unit)
{
    final switch (unit) {
    case RemoteTimeUnit.nanoseconds:
        return 1L;
    case RemoteTimeUnit.microseconds:
        return 1_000L;
    case RemoteTimeUnit.milliseconds:
        return 1_000_000L;
    case RemoteTimeUnit.seconds:
        return 1_000_000_000L;
    case RemoteTimeUnit.minutes:
        return 60L * 1_000_000_000L;
    case RemoteTimeUnit.hours:
        return 60L * 60L * 1_000_000_000L;
    case RemoteTimeUnit.days:
        return 24L * 60L * 60L * 1_000_000_000L;
    }
}

pure nothrow @nogc long timeout_to_nanos(long timeout, RemoteTimeUnit unit)
{
    const long factor = nanos_per_unit(unit);

    if (timeout > 0 && timeout > long.max / factor)
        return long.max;
    if (timeout < 0 && timeout < long.min / factor)
        return long.min;

    return timeout * factor;
}

/** Mirrors min(NANOSECONDS.toMillis(rem) + 1, 100). */
pure nothrow @nogc long wait_poll_sleep_millis(long remaining_nanos)
{
    if (remaining_nanos <= 0)
        return 0;

    long milliseconds = remaining_nanos / 1_000_000L + 1L;
    return milliseconds < 100L ? milliseconds : 100L;
}

struct RemoteProcessClientState {
    bool binder_present;
    bool output_stream_cached;
    bool input_stream_cached;
    bool in_reference_cache;

    void constructed() pure nothrow @nogc
    {
        binder_present = true;
        in_reference_cache = true;
    }

    void binder_died() pure nothrow @nogc
    {
        binder_present = false;
        in_reference_cache = false;
    }

    pure nothrow @nogc bool needs_output_stream()
    {
        if (output_stream_cached)
            return false;
        output_stream_cached = true;
        return true;
    }

    pure nothrow @nogc bool needs_input_stream()
    {
        if (input_stream_cached)
            return false;
        input_stream_cached = true;
        return true;
    }

    /** ShizukuRemoteProcess intentionally does not cache getErrorStream(). */
    pure nothrow @nogc bool needs_error_stream() const
    {
        return true;
    }
}

pure nothrow @nogc bool owner_death_should_destroy_process(bool process_alive)
{
    return process_alive;
}

module shizuku.user_service_launch;

import shizuku.user_handle : user_id;

struct UserServiceLaunchArgs {
    string debug_name;
    string token;
    string package_name;
    string class_name;
    int uid = -1;

    pure nothrow @nogc int user() const
    {
        return user_id(uid);
    }

    string effective_debug_name() const
    {
        if (debug_name !is null)
            return debug_name;

        // Java string concatenation renders a null reference as "null".
        return (package_name is null ? "null" : package_name) ~ ":user_service";
    }
}

private pure nothrow @nogc bool starts_with(string value, string prefix)
{
    if (value.length < prefix.length)
        return false;

    foreach (i; 0 .. prefix.length) {
        if (value[i] != prefix[i])
            return false;
    }
    return true;
}

private pure nothrow @nogc bool try_parse_decimal_int(string text, out int value)
{
    value = 0;
    if (text.length == 0)
        return false;

    size_t i;
    bool negative;

    if (text[i] == '-' || text[i] == '+') {
        negative = text[i] == '-';
        ++i;
        if (i == text.length)
            return false;
    }

    const ulong limit = negative
        ? cast(ulong) int.max + 1UL
        : cast(ulong) int.max;

    ulong magnitude;
    for (; i < text.length; ++i) {
        const char c = text[i];
        if (c < '0' || c > '9')
            return false;

        const ulong digit = cast(ulong)(c - '0');
        if (magnitude > (limit - digit) / 10UL)
            return false;

        magnitude = magnitude * 10UL + digit;
    }

    if (negative) {
        if (magnitude == cast(ulong) int.max + 1UL)
            value = int.min;
        else
            value = -cast(int) magnitude;
    } else {
        value = cast(int) magnitude;
    }
    return true;
}

/**
 * Parses UserService.create(String[] args). Unknown options are ignored and
 * later duplicate options overwrite earlier ones, exactly as in Java.
 *
 * Returns false where Integer.parseInt would throw.
 */
pure nothrow @nogc bool parse_user_service_launch_args(
    string[] args,
    out UserServiceLaunchArgs result)
{
    result = UserServiceLaunchArgs.init;

    foreach (arg; args) {
        if (starts_with(arg, "--debug-name=")) {
            result.debug_name = arg[13 .. $];
        } else if (starts_with(arg, "--token=")) {
            result.token = arg[8 .. $];
        } else if (starts_with(arg, "--package=")) {
            result.package_name = arg[10 .. $];
        } else if (starts_with(arg, "--class=")) {
            result.class_name = arg[8 .. $];
        } else if (starts_with(arg, "--uid=")) {
            if (!try_parse_decimal_int(arg[6 .. $], result.uid))
                return false;
        }
    }
    return true;
}

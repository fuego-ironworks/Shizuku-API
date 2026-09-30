module shizuku.system_properties;

private pure nothrow @nogc bool ascii_equal_ignore_case(string a, string b)
{
    if (a.length != b.length)
        return false;

    foreach (i; 0 .. a.length) {
        char x = a[i];
        char y = b[i];

        if (x >= 'A' && x <= 'Z')
            x = cast(char)(x + ('a' - 'A'));
        if (y >= 'A' && y <= 'Z')
            y = cast(char)(y + ('a' - 'A'));

        if (x != y)
            return false;
    }
    return true;
}

/** Exact Boolean.parseBoolean behavior for non-null/nullable D strings. */
pure nothrow @nogc bool parse_java_boolean(string value)
{
    return ascii_equal_ignore_case(value, "true");
}

private pure nothrow @nogc int digit_value(char c)
{
    if (c >= '0' && c <= '9')
        return c - '0';
    if (c >= 'a' && c <= 'f')
        return 10 + c - 'a';
    if (c >= 'A' && c <= 'F')
        return 10 + c - 'A';
    return -1;
}

/**
 * Integer.decode/Long.decode radix and sign rules:
 * decimal by default, 0x/0X/# hexadecimal, leading 0 octal.
 */
pure nothrow @nogc bool try_decode_java_long(string text, out long value)
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

    uint radix = 10;
    if (i + 1 < text.length && text[i] == '0'
            && (text[i + 1] == 'x' || text[i + 1] == 'X')) {
        radix = 16;
        i += 2;
    } else if (i < text.length && text[i] == '#') {
        radix = 16;
        ++i;
    } else if (i + 1 < text.length && text[i] == '0') {
        radix = 8;
        ++i;
    }

    if (i == text.length)
        return false;

    const ulong negative_limit = cast(ulong) long.max + 1UL;
    const ulong limit = negative ? negative_limit : cast(ulong) long.max;
    ulong magnitude;

    for (; i < text.length; ++i) {
        const int digit = digit_value(text[i]);
        if (digit < 0 || cast(uint) digit >= radix)
            return false;

        const ulong udigit = cast(ulong) digit;
        if (magnitude > (limit - udigit) / radix)
            return false;

        magnitude = magnitude * radix + udigit;
    }

    if (negative) {
        if (magnitude == negative_limit)
            value = long.min;
        else
            value = -cast(long) magnitude;
    } else {
        value = cast(long) magnitude;
    }
    return true;
}

pure nothrow @nogc bool try_decode_java_int(string text, out int value)
{
    long decoded;
    if (!try_decode_java_long(text, decoded)
            || decoded < int.min || decoded > int.max) {
        value = 0;
        return false;
    }

    value = cast(int) decoded;
    return true;
}

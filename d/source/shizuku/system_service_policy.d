module shizuku.system_service_policy;

string transaction_field_name(string method_name)
{
    return "TRANSACTION_" ~ method_name;
}

string transaction_cache_key(string class_name, string method_name)
{
    return class_name ~ "." ~ transaction_field_name(method_name);
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

/**
 * Mirrors the reflection fallback in SystemServiceHelper.getTransactionCode:
 * TRANSACTION_method_<digits>. TextUtils.isDigitsOnly returns true for an empty
 * sequence, so this intentionally does too.
 */
pure nothrow @nogc bool is_versioned_transaction_field(
    string candidate,
    string base_field_name)
{
    if (candidate.length < base_field_name.length + 1)
        return false;
    if (!starts_with(candidate, base_field_name))
        return false;
    if (candidate[base_field_name.length] != '_')
        return false;

    foreach (c; candidate[base_field_name.length + 1 .. $]) {
        if (c < '0' || c > '9')
            return false;
    }
    return true;
}

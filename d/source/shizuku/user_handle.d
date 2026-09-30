module shizuku.user_handle;

enum int PER_USER_RANGE = 100_000;

pure nothrow @nogc int user_id(int uid)
{
    return uid / PER_USER_RANGE;
}

pure nothrow @nogc int app_id(int uid)
{
    return uid % PER_USER_RANGE;
}

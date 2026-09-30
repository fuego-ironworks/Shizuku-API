module shizuku.abi_util;

/**
 * Java AbiUtil caches Build.SUPPORTED_32_BIT_ABIS.length > 0 on first use.
 * The Android boundary supplies that length; later changes are ignored.
 */
struct Abi32Cache {
    private int cached = -1;

    bool has_32_bit(int supported_32_bit_abi_count) pure nothrow @nogc
    {
        if (cached < 0)
            cached = supported_32_bit_abi_count > 0 ? 1 : 0;
        return cached != 0;
    }

    pure nothrow @nogc bool initialized() const
    {
        return cached >= 0;
    }
}

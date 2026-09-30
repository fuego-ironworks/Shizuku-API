module shizuku.binder_container;

/**
 * Semantic translation of provider BinderContainer.
 * Parcel encoding/decoding is supplied by the Android boundary.
 */
struct BinderContainer {
    void* binder;

    pure nothrow @nogc int describe_contents() const
    {
        return 0;
    }
}

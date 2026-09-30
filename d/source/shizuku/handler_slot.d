module shizuku.handler_slot;

class MainHandlerNotSet : Exception {
    this()
    {
        super("Please call setMainHandler first");
    }
}

/**
 * Opaque translation of HandlerUtil. Android Handler operations stay in the
 * framework boundary; this preserves the one mutable process-wide slot.
 */
class HandlerSlot {
    private void* handler;

    void set_main_handler(void* value) pure nothrow @nogc
    {
        handler = value;
    }

    void* get_main_handler()
    {
        if (handler is null)
            throw new MainHandlerNotSet;
        return handler;
    }

    bool is_set() const pure nothrow @nogc
    {
        return handler !is null;
    }
}

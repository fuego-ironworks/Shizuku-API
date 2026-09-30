module shizuku.rish_config;

enum int ATTY_IN = 1;
enum int ATTY_OUT = 1 << 1;
enum int ATTY_ERR = 1 << 2;

enum int TRANSACTION_CREATE_HOST = 0;
enum int TRANSACTION_SET_WINDOW_SIZE = 1;
enum int TRANSACTION_GET_EXIT_CODE = 2;

struct RishConfig {
    void* binder;
    string interface_token;
    int transaction_code_start;
    string library_path;

    int transaction_code(int code) const pure nothrow @nogc
    {
        return transaction_code_start + code;
    }

    void set_library_path(string path)
    {
        library_path = path;
    }

    void init_server(string token, int code_start)
    {
        binder = null;
        interface_token = token;
        transaction_code_start = code_start;
    }

    void init_client(void* binder_handle, string token, int code_start)
    {
        binder = binder_handle;
        interface_token = token;
        transaction_code_start = code_start;
    }

    /**
     * Mirrors System.loadLibrary("rish") vs System.load(path + "/librish.so").
     * A non-null empty path therefore intentionally yields "/librish.so".
     */
    bool uses_system_load_library() const pure nothrow @nogc
    {
        return library_path is null;
    }

    string library_to_load() const
    {
        return uses_system_load_library() ? "rish" : library_path ~ "/librish.so";
    }
}

module shizuku.sui_protocol;

enum uint BRIDGE_TRANSACTION_CODE =
    (cast(uint)'_' << 24) |
    (cast(uint)'S' << 16) |
    (cast(uint)'U' << 8) |
    cast(uint)'I';

enum string BRIDGE_SERVICE_DESCRIPTOR = "android.app.IActivityManager";
enum string BRIDGE_SERVICE_NAME = "activity";
enum int BRIDGE_ACTION_GET_BINDER = 2;

static assert(BRIDGE_TRANSACTION_CODE == 0x5f535549);

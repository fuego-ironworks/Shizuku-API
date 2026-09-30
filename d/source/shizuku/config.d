module shizuku.config;

/** Exact ConfigManager flag values from server-shared. */
enum int FLAG_ALLOWED = 1 << 1;
enum int FLAG_DENIED = 1 << 2;
enum int MASK_PERMISSION = FLAG_ALLOWED | FLAG_DENIED;

abstract class ConfigPackageEntry {
    abstract bool is_allowed();
    abstract bool is_denied();
}

/**
 * D form of ConfigManager. Persistence is deliberately left to the concrete
 * server implementation, as it is in the Java source.
 */
abstract class ConfigManager {
    abstract ConfigPackageEntry find(int uid);
    abstract void update(int uid, string[] packages, int mask, int values);
    abstract void remove(int uid);
}

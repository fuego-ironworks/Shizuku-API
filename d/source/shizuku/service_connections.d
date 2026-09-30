module shizuku.service_connections;

import shizuku.state : UserServiceArgs;

interface ServiceConnectionObserver {
    void on_service_connected(string component_class, void* binder);
    void on_service_disconnected(string component_class);
}

class ServiceConnectionState {
    private ServiceConnectionObserver[] connections;

    string component_class;
    void* binder;
    bool dead;

    this(UserServiceArgs args)
    {
        component_class = args.component_class;
    }

    bool add_connection(ServiceConnectionObserver connection)
    {
        if (connection is null)
            return false;

        foreach (current; connections) {
            if (current is connection)
                return false;
        }

        connections ~= connection;
        return true;
    }

    bool remove_connection(ServiceConnectionObserver connection)
    {
        if (connection is null)
            return false;

        foreach (i, current; connections) {
            if (current is connection) {
                for (size_t j = i; j + 1 < connections.length; ++j)
                    connections[j] = connections[j + 1];
                connections.length -= 1;
                return true;
            }
        }
        return false;
    }

    void clear_connections()
    {
        connections.length = 0;
    }

    size_t connection_count() const pure nothrow @nogc
    {
        return connections.length;
    }

    /**
     * Android ShizukuServiceConnection posts notify_connected() to the main
     * Handler, then retains the binder and links death. The boundary must keep
     * that scheduling order; this method represents the retained-binder step.
     */
    void retain_connected_binder(void* new_binder) pure nothrow @nogc
    {
        binder = new_binder;
    }

    void notify_connected()
    {
        foreach (connection; connections)
            connection.on_service_connected(component_class, binder);
    }

    /**
     * First death wins. Java clears binder before testing the dead flag.
     * The boundary should post notify_died_and_clear() to the main Handler and
     * then remove this object from the cache.
     */
    bool mark_died() pure nothrow @nogc
    {
        binder = null;

        if (dead)
            return false;

        dead = true;
        return true;
    }

    void notify_died_and_clear()
    {
        foreach (connection; connections)
            connection.on_service_disconnected(component_class);

        clear_connections();
    }
}

private struct CacheEntry {
    string key;
    ServiceConnectionState connection;
}

class ServiceConnectionCache {
    private CacheEntry[] entries;

    ServiceConnectionState get(UserServiceArgs args)
    {
        const string key = args.tag !is null ? args.tag : args.component_class;

        foreach (entry; entries) {
            if (entry.key == key)
                return entry.connection;
        }

        auto connection = new ServiceConnectionState(args);
        entries ~= CacheEntry(key, connection);
        return connection;
    }

    size_t remove(ServiceConnectionState connection)
    {
        size_t removed;
        size_t write;

        foreach (entry; entries) {
            if (entry.connection is connection) {
                ++removed;
                continue;
            }
            entries[write++] = entry;
        }
        entries.length = write;
        return removed;
    }

    size_t length() const pure nothrow @nogc
    {
        return entries.length;
    }
}

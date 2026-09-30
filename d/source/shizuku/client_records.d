module shizuku.client_records;

import shizuku.config;

/**
 * Typed semantic boundary for IShizukuApplication.dispatchRequestPermissionResult.
 * Binder/Bundle encoding belongs in the Android boundary.
 */
interface ApplicationCallback {
    void dispatch_request_permission_result(int request_code, bool allowed);
}

class ClientRecord {
    int uid;
    int pid;
    ApplicationCallback client;
    string package_name;
    int api_version;
    bool allowed;

    this(
        int uid,
        int pid,
        ApplicationCallback client,
        string package_name,
        int api_version)
    {
        this.uid = uid;
        this.pid = pid;
        this.client = client;
        this.package_name = package_name;
        this.api_version = api_version;
        this.allowed = false;
    }

    void dispatch_request_permission_result(int request_code, bool allowed)
    {
        client.dispatch_request_permission_result(request_code, allowed);
    }
}

class ClientStateException : Exception {
    this(string message)
    {
        super(message);
    }
}

class ClientPermissionException : Exception {
    this(string message)
    {
        super(message);
    }
}

/**
 * The Binder death registration itself is supplied by the Android boundary.
 * Returning false models linkToDeath throwing RemoteException.
 */
alias DeathRegistrar = bool delegate(ClientRecord record);

class ClientManager {
    private ConfigManager config_manager;
    private ClientRecord[] client_records;

    this(ConfigManager config_manager)
    {
        this.config_manager = config_manager;
    }

    ConfigManager get_config_manager()
    {
        return config_manager;
    }

    ClientRecord[] find_clients(int uid)
    {
        ClientRecord[] result;
        foreach (record; client_records) {
            if (record.uid == uid)
                result ~= record;
        }
        return result;
    }

    ClientRecord find_client(int uid, int pid)
    {
        foreach (record; client_records) {
            if (record.pid == pid && record.uid == uid)
                return record;
        }
        return null;
    }

    ClientRecord require_client(int uid, int pid, bool requires_permission = false)
    {
        auto record = find_client(uid, pid);
        if (record is null)
            throw new ClientStateException("Not an attached client");

        if (requires_permission && !record.allowed)
            throw new ClientPermissionException("Caller has no permission");

        return record;
    }

    ClientRecord add_client(
        int uid,
        int pid,
        ApplicationCallback client,
        string package_name,
        int api_version,
        DeathRegistrar register_death = null)
    {
        auto record = new ClientRecord(uid, pid, client, package_name, api_version);

        auto entry = config_manager.find(uid);
        if (entry !is null && entry.is_allowed())
            record.allowed = true;

        if (register_death !is null && !register_death(record))
            return null;

        client_records ~= record;
        return record;
    }

    bool remove_client(ClientRecord record)
    {
        foreach (i, current; client_records) {
            if (current is record) {
                for (size_t j = i; j + 1 < client_records.length; ++j)
                    client_records[j] = client_records[j + 1];
                client_records.length -= 1;
                return true;
            }
        }
        return false;
    }

    size_t length() const pure nothrow @nogc
    {
        return client_records.length;
    }
}

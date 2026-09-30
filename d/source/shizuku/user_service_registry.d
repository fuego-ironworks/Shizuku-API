module shizuku.user_service_registry;

import shizuku.user_service :
    UserServiceRecordState,
    begin_starting;
import shizuku.user_service_manager_policy :
    ExistingRecordDecision,
    existing_record_decision,
    peek_result,
    user_service_key;

class ManagedUserServiceRecord {
    string key;
    string package_name;
    string token;
    UserServiceRecordState state;
    bool active = true;
    bool destroyed;

    private void*[] callbacks;

    this(
        string key,
        string package_name,
        string token,
        int version_code,
        bool daemon)
    {
        this.key = key;
        this.package_name = package_name;
        this.token = token;
        state.version_code = version_code;
        state.daemon = daemon;
    }

    bool register_callback(void* connection)
    {
        if (connection is null)
            return false;

        foreach (current; callbacks) {
            if (current is connection)
                return false;
        }

        callbacks ~= connection;
        state.callback_count = callbacks.length;
        return true;
    }

    bool unregister_callback(void* connection)
    {
        if (connection is null)
            return false;

        foreach (i, current; callbacks) {
            if (current is connection) {
                for (size_t j = i; j + 1 < callbacks.length; ++j)
                    callbacks[j] = callbacks[j + 1];
                callbacks.length -= 1;
                state.callback_count = callbacks.length;
                return true;
            }
        }
        return false;
    }

    void kill_callbacks()
    {
        callbacks.length = 0;
        state.callback_count = 0;
    }

    size_t callback_count() const pure nothrow @nogc
    {
        return callbacks.length;
    }
}

private struct PackageRecords {
    string package_name;
    ManagedUserServiceRecord[] records;
}

struct AddUserServiceResult {
    bool valid;
    int result;
    ManagedUserServiceRecord record;
    bool created;
    bool replaced;
    bool callback_registered;
    bool broadcast_existing_binder;
    bool start_process;
}

struct RemoveUserServiceResult {
    bool valid;
    int result;
    bool removed_record;
    bool callback_unregistered;
}

/**
 * Framework-free translation of UserServiceManager's record tables.
 *
 * Package ownership checks, PackageInfo lookup, Binder liveness probes and
 * actual process launch are boundary inputs. The registry preserves the
 * upstream record replacement, callback and package-index behavior.
 */
class UserServiceRegistry {
    private ManagedUserServiceRecord[] active_records;
    private PackageRecords[] package_records;

    ManagedUserServiceRecord find(string key)
    {
        foreach (record; active_records) {
            if (record.key == key)
                return record;
        }
        return null;
    }

    size_t active_count() const pure nothrow @nogc
    {
        return active_records.length;
    }

    private void remember_package_record(ManagedUserServiceRecord record)
    {
        foreach (ref group; package_records) {
            if (group.package_name == record.package_name) {
                group.records ~= record;
                return;
            }
        }

        PackageRecords group;
        group.package_name = record.package_name;
        group.records ~= record;
        package_records ~= group;
    }

    private ManagedUserServiceRecord create_record(
        string key,
        string package_name,
        string token,
        int version_code,
        bool daemon)
    {
        auto record = new ManagedUserServiceRecord(
            key,
            package_name,
            token,
            version_code,
            daemon
        );
        active_records ~= record;
        remember_package_record(record);
        return record;
    }

    bool remove_record(ManagedUserServiceRecord record)
    {
        if (record is null)
            return false;

        foreach (i, current; active_records) {
            if (current is record) {
                for (size_t j = i; j + 1 < active_records.length; ++j)
                    active_records[j] = active_records[j + 1];
                active_records.length -= 1;

                record.active = false;
                record.destroyed = true;
                record.kill_callbacks();
                return true;
            }
        }
        return false;
    }

    AddUserServiceResult add(
        string package_name,
        string class_name,
        string tag,
        int version_code,
        bool daemon,
        bool no_create,
        int calling_api_version,
        void* connection,
        bool existing_service_alive,
        string new_token)
    {
        AddUserServiceResult result;

        if (package_name is null
                || class_name is null
                || connection is null) {
            return result;
        }

        result.valid = true;
        const string key = user_service_key(
            package_name,
            tag,
            class_name
        );
        auto record = find(key);

        if (no_create) {
            if (record !is null)
                result.callback_registered =
                    record.register_callback(connection);

            const bool alive = record !is null
                && record.state.binder_present
                && existing_service_alive;

            result.record = record;
            result.result = peek_result(
                record !is null,
                alive,
                record is null ? 0 : record.state.version_code,
                calling_api_version
            );
            result.broadcast_existing_binder = alive;
            return result;
        }

        const ExistingRecordDecision decision =
            existing_record_decision(
                record !is null,
                record is null ? 0 : record.state.version_code,
                version_code,
                record is null ? false : record.state.starting,
                record is null ? false : record.state.binder_present,
                existing_service_alive
            );

        final switch (decision) {
        case ExistingRecordDecision.create_new:
            record = create_record(
                key,
                package_name,
                new_token,
                version_code,
                daemon
            );
            result.created = true;
            break;

        case ExistingRecordDecision.replace_version_mismatch:
        case ExistingRecordDecision.replace_dead:
            result.replaced = remove_record(record);
            record = create_record(
                key,
                package_name,
                new_token,
                version_code,
                daemon
            );
            result.created = true;
            break;

        case ExistingRecordDecision.reuse_existing:
            if (record.state.daemon != daemon)
                record.state.daemon = daemon;
            break;
        }

        result.record = record;
        result.callback_registered =
            record.register_callback(connection);

        const bool alive =
            record.state.binder_present && existing_service_alive;
        if (alive) {
            result.broadcast_existing_binder = true;
        } else if (begin_starting(record.state)) {
            result.start_process = true;
        }

        result.result = 0;
        return result;
    }

    RemoveUserServiceResult remove(
        string package_name,
        string class_name,
        string tag,
        bool remove_service,
        void* connection)
    {
        RemoveUserServiceResult result;

        if (package_name is null || class_name is null)
            return result;

        result.valid = true;
        const string key = user_service_key(
            package_name,
            tag,
            class_name
        );
        auto record = find(key);

        if (record is null) {
            result.result = 1;
            return result;
        }

        if (remove_service)
            result.removed_record = remove_record(record);
        else
            result.callback_unregistered =
                record.unregister_callback(connection);

        result.result = 0;
        return result;
    }

    /**
     * The Java package index intentionally retains records removed individually.
     * Package removal therefore visits historical entries as well as live ones.
     */
    size_t remove_for_package(string package_name)
    {
        foreach (i, ref group; package_records) {
            if (group.package_name != package_name)
                continue;

            size_t removed;
            foreach (record; group.records) {
                if (remove_record(record))
                    ++removed;
            }

            for (size_t j = i; j + 1 < package_records.length; ++j)
                package_records[j] = package_records[j + 1];
            package_records.length -= 1;
            return removed;
        }
        return 0;
    }

    size_t package_history_count(string package_name) const
    {
        foreach (group; package_records) {
            if (group.package_name == package_name)
                return group.records.length;
        }
        return 0;
    }
}

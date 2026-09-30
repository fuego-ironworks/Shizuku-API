module shizuku.listeners;

import shizuku.state : ServerState;

alias VoidListener = void delegate();
alias PermissionListener = void delegate(int request_code, int result);
alias VoidPoster = void delegate(VoidListener listener);
alias PermissionPoster =
    void delegate(PermissionListener listener, int request_code, int result);
alias MainThreadProbe = bool delegate();

private struct VoidHolder {
    VoidListener listener;
    VoidPoster poster;
}

private struct PermissionHolder {
    PermissionListener listener;
    PermissionPoster poster;
}

/**
 * Android Handler/Looper are supplied by the boundary as poster delegates.
 * Ordering follows Shizuku.java: received callbacks run/post first, then
 * binder_ready becomes true.
 */
class ListenerRegistry {
    private ServerState* state;
    private VoidPoster main_void_poster;
    private PermissionPoster main_permission_poster;
    private MainThreadProbe on_main_thread;

    private VoidHolder[] received;
    private VoidHolder[] dead;
    private PermissionHolder[] permission;

    this(
        ServerState* state,
        VoidPoster main_void_poster,
        PermissionPoster main_permission_poster,
        MainThreadProbe on_main_thread)
    {
        this.state = state;
        this.main_void_poster = main_void_poster;
        this.main_permission_poster = main_permission_poster;
        this.on_main_thread = on_main_thread;
    }

    private bool main_now()
    {
        return on_main_thread !is null && on_main_thread();
    }

    private void dispatch(VoidHolder holder)
    {
        if (holder.poster !is null) {
            holder.poster(holder.listener);
        } else if (main_now()) {
            holder.listener();
        } else if (main_void_poster !is null) {
            main_void_poster(holder.listener);
        }
    }

    private void dispatch(
        PermissionHolder holder,
        int request_code,
        int result)
    {
        if (holder.poster !is null) {
            holder.poster(holder.listener, request_code, result);
        } else if (main_now()) {
            holder.listener(request_code, result);
        } else if (main_permission_poster !is null) {
            main_permission_poster(holder.listener, request_code, result);
        }
    }

    void add_received(
        VoidListener listener,
        bool sticky = false,
        VoidPoster poster = null)
    {
        if (listener is null)
            return;

        if (sticky && state !is null && state.binder_ready)
            dispatch(VoidHolder(listener, poster));

        received ~= VoidHolder(listener, poster);
    }

    bool remove_received(VoidListener listener)
    {
        return remove_void(received, listener);
    }

    void add_dead(VoidListener listener, VoidPoster poster = null)
    {
        if (listener !is null)
            dead ~= VoidHolder(listener, poster);
    }

    bool remove_dead(VoidListener listener)
    {
        return remove_void(dead, listener);
    }

    void add_permission(
        PermissionListener listener,
        PermissionPoster poster = null)
    {
        if (listener !is null)
            permission ~= PermissionHolder(listener, poster);
    }

    bool remove_permission(PermissionListener listener)
    {
        foreach (i, holder; permission) {
            if (holder.listener == listener) {
                erase_permission(i);
                return true;
            }
        }
        return false;
    }

    void schedule_received()
    {
        foreach (holder; received)
            dispatch(holder);

        if (state !is null)
            state.binder_ready = true;
    }

    void schedule_dead()
    {
        foreach (holder; dead)
            dispatch(holder);
    }

    void schedule_permission(int request_code, int result)
    {
        foreach (holder; permission)
            dispatch(holder, request_code, result);
    }

    size_t received_count() const pure nothrow @nogc
    {
        return received.length;
    }

    size_t dead_count() const pure nothrow @nogc
    {
        return dead.length;
    }

    size_t permission_count() const pure nothrow @nogc
    {
        return permission.length;
    }

    private static bool remove_void(
        ref VoidHolder[] values,
        VoidListener listener)
    {
        foreach (i, holder; values) {
            if (holder.listener == listener) {
                for (size_t j = i; j + 1 < values.length; ++j)
                    values[j] = values[j + 1];
                values.length -= 1;
                return true;
            }
        }
        return false;
    }

    private void erase_permission(size_t i)
    {
        for (size_t j = i; j + 1 < permission.length; ++j)
            permission[j] = permission[j + 1];
        permission.length -= 1;
    }
}

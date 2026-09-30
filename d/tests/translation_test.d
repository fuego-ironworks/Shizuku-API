module translation_test;

import shizuku.binder_wrapper_protocol;
import shizuku.client_records;
import shizuku.config;
import shizuku.provider_protocol;
import shizuku.rish_config;
import shizuku.state;
import shizuku.sui_protocol;
import shizuku.user_handle;
import shizuku.user_service;

final class TestEntry : ConfigPackageEntry {
    bool allowed;
    bool denied;

    override bool is_allowed()
    {
        return allowed;
    }

    override bool is_denied()
    {
        return denied;
    }
}

final class TestConfig : ConfigManager {
    ConfigPackageEntry entry;

    override ConfigPackageEntry find(int uid)
    {
        return entry;
    }

    override void update(int uid, string[] packages, int mask, int values)
    {
    }

    override void remove(int uid)
    {
    }
}

final class TestCallback : ApplicationCallback {
    int request_code;
    bool allowed;

    override void dispatch_request_permission_result(int request_code, bool allowed)
    {
        this.request_code = request_code;
        this.allowed = allowed;
    }
}

unittest {
    UserServiceArgs args;
    args.component_class = "example.Service";

    assert(args.connection_key() == "example.Service");

    args.tag = "";
    assert(args.connection_key() == "");
}

unittest {
    ServerState state;
    state.bind_application(2000, 13, 6, "u:r:shell:s0", true, true);
    state.pre_v11 = true;

    state.binder_lost();

    assert(state.uid == -1);
    assert(state.api_version == -1);
    assert(state.security_context is null);
    assert(!state.binder_ready);

    // Exact upstream binder-death behavior: these survive.
    assert(state.patch_version == 6);
    assert(state.permission_granted);
    assert(state.should_show_permission_rationale);
    assert(state.pre_v11);
}

unittest {
    UserServiceArgs args;
    args.component_class = "example.Service";

    UserServiceAddOptions add;
    assert(!build_add_options(args, false, add));

    args.process_name = "";
    args.tag = "";
    assert(build_add_options(args, true, add));
    assert(add.no_create);
    assert(add.has_tag);
    assert(add.tag == "");

    assert(supports_connection_detach(13, 4));
    assert(!supports_connection_detach(13, 3));
    assert(supports_connection_detach(14, 0));
}

unittest {
    auto p13 = forwarding_plan(false, 13, 7);
    assert(p13.include_inner_flags);
    assert(p13.outer_flags == 0);

    auto p12 = forwarding_plan(false, 12, 7);
    assert(!p12.include_inner_flags);
    assert(p12.outer_flags == 7);
}

unittest {
    assert(validate_provider_info(false, true) == ProviderInfoResult.ok);
    assert(validate_provider_info(true, true) == ProviderInfoResult.multiprocess_must_be_false);
    assert(validate_provider_info(false, false) == ProviderInfoResult.exported_must_be_true);
    assert(should_accept_sent_binder(false, true));
    assert(!should_accept_sent_binder(true, true));
    assert(can_reply_with_binder(true, true));
}

unittest {
    RishConfig config;
    config.init_server("token", 100);
    assert(config.transaction_code(TRANSACTION_GET_EXIT_CODE) == 102);
    assert(config.library_to_load() == "rish");

    config.set_library_path("");
    assert(config.library_to_load() == "/librish.so");
}

unittest {
    assert(user_id(200_123) == 2);
    assert(app_id(200_123) == 123);
    assert(BRIDGE_TRANSACTION_CODE == 0x5f535549);
}

unittest {
    auto entry = new TestEntry;
    entry.allowed = true;

    auto config = new TestConfig;
    config.entry = entry;

    auto callback = new TestCallback;
    auto manager = new ClientManager(config);

    auto record = manager.add_client(
        10001,
        77,
        callback,
        "example.package",
        13,
        (ClientRecord r) { return true; });

    assert(record !is null);
    assert(record.allowed);
    assert(manager.require_client(10001, 77, true) is record);

    record.dispatch_request_permission_result(9, true);
    assert(callback.request_code == 9);
    assert(callback.allowed);

    assert(manager.remove_client(record));
    assert(manager.length == 0);
}


import shizuku.service_policy;
import shizuku.system_service_policy;
import shizuku.user_service_manager_policy;

unittest {
    assert(user_service_key("pkg", null, "Service") == "pkg:Service");
    assert(user_service_key("pkg", "", "Service") == "pkg:");

    assert(remove_option(false, false));
    assert(!remove_option(true, false));

    assert(peek_result(true, true, 7, 13) == 7);
    assert(peek_result(true, true, 7, 12) == 0);
    assert(peek_result(false, false, 0, 13) == -1);
    assert(peek_result(false, false, 0, 12) == 1);

    assert(existing_record_decision(false, 0, 1, false, false, false)
        == ExistingRecordDecision.create_new);
    assert(existing_record_decision(true, 1, 2, false, true, true)
        == ExistingRecordDecision.replace_version_mismatch);
    assert(existing_record_decision(true, 1, 1, false, false, false)
        == ExistingRecordDecision.replace_dead);
    assert(existing_record_decision(true, 1, 1, true, false, false)
        == ExistingRecordDecision.reuse_existing);
}

unittest {
    assert(manager_permission_decision(10, 10, false)
        == ManagerPermissionDecision.allow);
    assert(calling_permission_decision(1000, 2000, false, false, false)
        == CallingPermissionDecision.deny_unattached);
    assert(calling_permission_decision(1000, 2000, false, true, false)
        == CallingPermissionDecision.deny_permission);
    assert(calling_permission_decision(1000, 2000, false, true, true)
        == CallingPermissionDecision.allow);

    assert(permission_request_action(1000, 20, 2000, 30, true, false)
        == PermissionRequestAction.reply_allowed);
    assert(permission_request_action(1000, 20, 2000, 30, false, true)
        == PermissionRequestAction.reply_denied);
    assert(permission_request_action(1000, 20, 2000, 30, false, false)
        == PermissionRequestAction.show_confirmation);

    assert(effective_calling_api_version(false, 0) == 13);
    assert(remote_target_flags(true, 13, 7, 3) == 7);
    assert(remote_target_flags(true, 12, 7, 3) == 3);
}

unittest {
    assert(transaction_field_name("getInstalledPackages")
        == "TRANSACTION_getInstalledPackages");
    assert(transaction_cache_key("android.foo.Stub", "bar")
        == "android.foo.Stub.TRANSACTION_bar");

    assert(is_versioned_transaction_field("TRANSACTION_bar_2", "TRANSACTION_bar"));
    assert(is_versioned_transaction_field("TRANSACTION_bar_", "TRANSACTION_bar"));
    assert(!is_versioned_transaction_field("TRANSACTION_bar_x", "TRANSACTION_bar"));
}


import shizuku.binder_container;
import shizuku.remote_process;
import shizuku.rish_host_policy;
import shizuku.rish_service_policy;
import shizuku.rish_terminal_policy;
import shizuku.service_connections;
import shizuku.system_properties;
import shizuku.user_service_launch;

unittest {
    int iv;
    long lv;

    assert(try_decode_java_int("42", iv) && iv == 42);
    assert(try_decode_java_int("0x2a", iv) && iv == 42);
    assert(try_decode_java_int("#2A", iv) && iv == 42);
    assert(try_decode_java_int("052", iv) && iv == 42);
    assert(try_decode_java_int("-0x80000000", iv) && iv == int.min);
    assert(!try_decode_java_int("0x80000000", iv));

    assert(try_decode_java_long("-0x8000000000000000", lv) && lv == long.min);
    assert(!try_decode_java_long("0x8000000000000000", lv));

    assert(parse_java_boolean("true"));
    assert(parse_java_boolean("TrUe"));
    assert(!parse_java_boolean("1"));
    assert(!parse_java_boolean(null));
}

final class TestServiceObserver : ServiceConnectionObserver {
    int connected_count;
    int disconnected_count;

    override void on_service_connected(string component_class, void* binder)
    {
        ++connected_count;
    }

    override void on_service_disconnected(string component_class)
    {
        ++disconnected_count;
    }
}

unittest {
    UserServiceArgs args;
    args.component_class = "example.Service";
    args.tag = "";

    auto cache = new ServiceConnectionCache;
    auto a = cache.get(args);
    auto b = cache.get(args);
    assert(a is b);
    assert(cache.length == 1);

    auto observer = new TestServiceObserver;
    assert(a.add_connection(observer));
    assert(!a.add_connection(observer));

    a.retain_connected_binder(cast(void*) 1);
    a.notify_connected();
    assert(observer.connected_count == 1);

    assert(a.mark_died());
    assert(!a.mark_died());
    a.notify_died_and_clear();
    assert(observer.disconnected_count == 1);
    assert(a.connection_count == 0);

    assert(cache.remove(a) == 1);
    assert(cache.length == 0);
}

unittest {
    UserServiceLaunchArgs args;
    assert(parse_user_service_launch_args([
        "--package=example.pkg",
        "--class=example.Service",
        "--uid=200123",
        "--token=abc",
        "--debug-name=first",
        "--debug-name=second"
    ], args));

    assert(args.package_name == "example.pkg");
    assert(args.class_name == "example.Service");
    assert(args.token == "abc");
    assert(args.debug_name == "second");
    assert(args.user == 2);
    assert(args.effective_debug_name == "second");

    UserServiceLaunchArgs defaults;
    assert(parse_user_service_launch_args(["--package=example.pkg"], defaults));
    assert(defaults.effective_debug_name == "example.pkg:user_service");

    assert(!parse_user_service_launch_args(["--uid=nope"], defaults));
}

unittest {
    RemoteTimeUnit unit;
    assert(parse_time_unit("SECONDS", unit));
    assert(unit == RemoteTimeUnit.seconds);
    assert(timeout_to_nanos(2, unit) == 2_000_000_000L);
    assert(wait_poll_sleep_millis(1) == 1);
    assert(wait_poll_sleep_millis(99_000_000) == 100);

    RemoteProcessClientState state;
    state.constructed();
    assert(state.binder_present && state.in_reference_cache);
    assert(state.needs_output_stream());
    assert(!state.needs_output_stream());
    assert(state.needs_error_stream());
    state.binder_died();
    assert(!state.binder_present && !state.in_reference_cache);
}

unittest {
    ubyte[] block;
    assert(c_bytes_for_string_array(["sh", "-c", "echo"], block));
    assert(block.length == 11);
    assert(block[2] == 0);
    assert(block[5] == 0);
    assert(block[$ - 1] == 0);

    auto plan = tty_plan(cast(ubyte)(ATTY_IN | ATTY_OUT));
    assert(plan.needs_ptmx());
    assert(!plan.needs_stdin_pipe());
    assert(!plan.needs_stdout_pipe());
    assert(plan.needs_stderr_pipe());

    assert(shell_argv(["-c", "id"])[0] == "/system/bin/sh");
    assert(!use_explicit_environment(-1));
    assert(!use_explicit_environment(0));
    assert(use_explicit_environment(1));
}

unittest {
    assert(!preserve_environment(false, ["PATH=/bin"]));
    assert(preserve_environment(false, ["RISH_PRESERVE_ENV=1"]));
    assert(!preserve_environment(true, ["RISH_PRESERVE_ENV=0"]));
    assert(preserve_environment(true, [
        "RISH_PRESERVE_ENV=1",
        "RISH_PRESERVE_ENV=0"
    ]));

    assert(classify_rish_transaction(30_000, 30_000) == RishTransaction.create_host);
    assert(classify_rish_transaction(30_002, 30_000) == RishTransaction.get_exit_code);
    assert(!create_host_should_decode(false, false));
    assert(!create_host_should_decode(true, true));
    assert(create_host_should_decode(true, false));
}

unittest {
    assert(detect_tty(true, true, true) == ATTY_ALL);
    assert(selected_tty_fd(ATTY_OUT) == 1);
    assert(makes_terminal_raw(ATTY_ALL));
    assert(blocks_sigwinch(ATTY_OUT));
    assert(needs_client_stderr_pipe(0));

    auto fds = upstream_terminal_native_fds(10, 11, 12);
    assert(fds.stdin_fd == 10);
    assert(fds.stdout_fd == 11);
    assert(fds.stderr_fd == 11);
}

unittest {
    BinderContainer container;
    container.binder = cast(void*) 1;
    assert(container.describe_contents() == 0);
}

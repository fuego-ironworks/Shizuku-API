module state_test;

import shizuku.state;
import shizuku.service_protocol;

unittest {
    ServerState state;
    assert(state.uid == -1);
    assert(!state.binder_ready);

    state.bind_application(2000, 13, 6, "u:r:shell:s0", true, false);
    assert(state.uid == 2000);
    assert(state.api_version == 13);
    assert(state.permission_result() == PERMISSION_GRANTED);
    assert(state.binder_ready);

    state.reset();
    assert(state.uid == -1);
    assert(!state.binder_ready);
}

unittest {
    UserServiceArgs args;
    args.component_class = "example.Service";
    assert(args.connection_key() == "example.Service");
    args.tag = "stable";
    assert(args.connection_key() == "stable");
}

unittest {
    assert(transaction(ServiceMethodId.attach_application) == 18);
    assert(peek_user_service_result(false, 13, 7) == 7);
    assert(peek_user_service_result(false, 12, 7) == -1);
    assert(peek_user_service_result(false, 12, 0) == 0);
}

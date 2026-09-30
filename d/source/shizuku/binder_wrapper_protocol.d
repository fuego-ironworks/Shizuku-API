module shizuku.binder_wrapper_protocol;

/**
 * Parcel framing decision made by ShizukuBinderWrapper.transact().
 * Actual Parcel writes and Binder calls remain in the Android boundary.
 */
struct BinderForwardingPlan {
    bool at_least_13;
    bool include_inner_flags;
    int outer_flags;
}

pure nothrow @nogc BinderForwardingPlan forwarding_plan(
    bool pre_v11,
    int server_version,
    int original_flags)
{
    const bool at_least_13 = !pre_v11 && server_version >= 13;

    BinderForwardingPlan plan;
    plan.at_least_13 = at_least_13;
    plan.include_inner_flags = at_least_13;
    plan.outer_flags = at_least_13 ? 0 : original_flags;
    return plan;
}

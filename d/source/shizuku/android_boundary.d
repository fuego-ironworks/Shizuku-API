module shizuku.android_boundary;

public import ick.android;

/**
 * Deliberately thin Android boundary.  ABI declarations live in Ick DMD.
 * Shizuku protocol/state modules must not redeclare Binder or Parcel ABIs.
 */

bool binder_alive(AIBinder* binder) nothrow @nogc
{
    return binder !is null && AIBinder_ping(binder) == STATUS_OK;
}

void retain_binder(AIBinder* binder) nothrow @nogc
{
    if (binder !is null)
        AIBinder_incStrong(binder);
}

void release_binder(AIBinder* binder) nothrow @nogc
{
    if (binder !is null)
        AIBinder_decStrong(binder);
}

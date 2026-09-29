module shizuku.api_constants;

enum int SERVER_VERSION = 13;
enum int SERVER_PATCH_VERSION = 6;

enum string BINDER_DESCRIPTOR = "moe.shizuku.server.IShizukuService";
enum uint BINDER_TRANSACTION_transact = 1;

enum int USER_SERVICE_TRANSACTION_destroy = 16_777_115;

enum string USER_SERVICE_ARG_TAG = "shizuku:user-service-arg-tag";
enum string USER_SERVICE_ARG_COMPONENT = "shizuku:user-service-arg-component";
enum string USER_SERVICE_ARG_DEBUGGABLE = "shizuku:user-service-arg-debuggable";
enum string USER_SERVICE_ARG_VERSION_CODE = "shizuku:user-service-arg-version-code";
enum string USER_SERVICE_ARG_PROCESS_NAME = "shizuku:user-service-arg-process-name";
enum string USER_SERVICE_ARG_NO_CREATE = "shizuku:user-service-arg-no-create";
enum string USER_SERVICE_ARG_DAEMON = "shizuku:user-service-arg-daemon";
enum string USER_SERVICE_ARG_USE_32_BIT_APP_PROCESS = "shizuku:user-service-arg-use-32-bit-app-process";
enum string USER_SERVICE_ARG_REMOVE = "shizuku:user-service-remove";
enum string USER_SERVICE_ARG_TOKEN = "shizuku:user-service-arg-token";

enum string BIND_APPLICATION_SERVER_VERSION = "shizuku:attach-reply-version";
enum string BIND_APPLICATION_SERVER_PATCH_VERSION = "shizuku:attach-reply-patch-version";
enum string BIND_APPLICATION_SERVER_UID = "shizuku:attach-reply-uid";
enum string BIND_APPLICATION_SERVER_SECONTEXT = "shizuku:attach-reply-secontext";
enum string BIND_APPLICATION_PERMISSION_GRANTED = "shizuku:attach-reply-permission-granted";
enum string BIND_APPLICATION_SHOULD_SHOW_REQUEST_PERMISSION_RATIONALE = "shizuku:attach-reply-should-show-request-permission-rationale";

enum string REQUEST_PERMISSION_REPLY_ALLOWED = "shizuku:request-permission-reply-allowed";
enum string REQUEST_PERMISSION_REPLY_IS_ONETIME = "shizuku:request-permission-reply-is-onetime";

enum string ATTACH_APPLICATION_PACKAGE_NAME = "shizuku:attach-package-name";
enum string ATTACH_APPLICATION_API_VERSION = "shizuku:attach-api-version";

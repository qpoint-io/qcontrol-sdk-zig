/**
 * @file qcontrol/exec.h
 * @brief Exec operation types for qcontrol SDK
 *
 * Defines the session-based exec plugin model where:
 * - Configuration happens per-exec at spawn time (not globally)
 * - State flows automatically between I/O operations on the same process
 * - Declarative transforms (prefix, suffix, replace) require zero code
 * - Modifications to argv, env, cwd are declarative fields
 * - The agent handles heavy lifting; SDKs are thin wrappers
 *
 * NOTE: This API is v1 spec only. Callbacks currently return "not implemented".
 */

#ifndef QCONTROL_EXEC_H
#define QCONTROL_EXEC_H

#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * Exec Action Types
 * ============================================================================ */

/**
 * Action types returned by exec operation callbacks.
 */
typedef enum {
    /** No interception, continue normally */
    QCONTROL_EXEC_ACTION_PASS = 0,
    /** Block the operation with EACCES */
    QCONTROL_EXEC_ACTION_BLOCK = 1,
    /** Block the operation with a specific errno */
    QCONTROL_EXEC_ACTION_BLOCK_ERRNO = 2,
    /** Intercept with full session config */
    QCONTROL_EXEC_ACTION_SESSION = 3,
    /** Track state only, no transforms */
    QCONTROL_EXEC_ACTION_STATE = 4,
} qcontrol_exec_action_type_t;

/* ============================================================================
 * Exec Pattern Replacement
 * ============================================================================ */

/**
 * Pattern for string replacement in transform pipeline.
 */
typedef struct {
    const char* needle;
    size_t needle_len;
    const char* replacement;
    size_t replacement_len;
} qcontrol_exec_pattern_t;

/* ============================================================================
 * Forward Declarations
 * ============================================================================ */

typedef struct qcontrol_buffer qcontrol_buffer_t;
typedef struct qcontrol_exec_ctx qcontrol_exec_ctx_t;
typedef struct qcontrol_exec_rw_config qcontrol_exec_rw_config_t;
typedef struct qcontrol_exec_session qcontrol_exec_session_t;
typedef struct qcontrol_exec_action qcontrol_exec_action_t;

/* ============================================================================
 * Exec Transform Function Types
 * ============================================================================ */

/**
 * Transform function - called during stdin/stdout/stderr to modify buffer.
 *
 * @param state Plugin-defined state (from session)
 * @param ctx Exec context (pid, path, argv)
 * @param buf Buffer containing data to transform
 * @return Action indicating whether to continue or block
 */
typedef qcontrol_exec_action_t (*qcontrol_exec_transform_fn)(
    void* state,
    qcontrol_exec_ctx_t* ctx,
    qcontrol_buffer_t* buf
);

/**
 * Dynamic prefix function - returns prefix to prepend.
 *
 * @param state Plugin-defined state
 * @param ctx Exec context
 * @param out_len Output parameter for prefix length
 * @return Prefix string (plugin-owned, must remain valid until exit)
 */
typedef const char* (*qcontrol_exec_prefix_fn)(
    void* state,
    qcontrol_exec_ctx_t* ctx,
    size_t* out_len
);

/**
 * Dynamic suffix function - returns suffix to append.
 *
 * @param state Plugin-defined state
 * @param ctx Exec context
 * @param out_len Output parameter for suffix length
 * @return Suffix string (plugin-owned, must remain valid until exit)
 */
typedef const char* (*qcontrol_exec_suffix_fn)(
    void* state,
    qcontrol_exec_ctx_t* ctx,
    size_t* out_len
);

/* ============================================================================
 * Exec Configuration Structures
 * ============================================================================ */

/**
 * Read/Write configuration for exec I/O (stdin/stdout/stderr).
 *
 * Transform order: prefix -> replace -> transform -> suffix
 */
struct qcontrol_exec_rw_config {
    /** Static prefix to prepend (or NULL) */
    const char* prefix;
    size_t prefix_len;

    /** Static suffix to append (or NULL) */
    const char* suffix;
    size_t suffix_len;

    /** Dynamic prefix function (or NULL) */
    qcontrol_exec_prefix_fn prefix_fn;

    /** Dynamic suffix function (or NULL) */
    qcontrol_exec_suffix_fn suffix_fn;

    /** Pattern replacements array (or NULL) */
    const qcontrol_exec_pattern_t* replace;
    size_t replace_count;

    /** Custom transform function (or NULL) */
    qcontrol_exec_transform_fn transform;
};

/**
 * Session configuration for an exec.
 * Returned from on_exec to configure I/O behavior and modifications.
 */
struct qcontrol_exec_session {
    /** Plugin-defined state (opaque, plugin owns memory) */
    void* state;

    /* === MODIFICATIONS (NULL = no change) === */

    /** Replace executable path */
    const char* set_path;

    /** Replace all arguments (NULL-terminated array) */
    const char* const* set_argv;

    /** Arguments to prepend before existing (NULL-terminated array) */
    const char* const* prepend_argv;

    /** Arguments to append after existing (NULL-terminated array) */
    const char* const* append_argv;

    /** Environment KEY=VALUE pairs to add/override (NULL-terminated array) */
    const char* const* set_env;

    /** Environment keys to remove (NULL-terminated array) */
    const char* const* unset_env;

    /** Replace working directory */
    const char* set_cwd;

    /* === I/O TRANSFORM CONFIGS === */

    /** Stdin transform config (NULL if no transforms) */
    qcontrol_exec_rw_config_t* stdin_config;

    /** Stdout transform config (NULL if no transforms) */
    qcontrol_exec_rw_config_t* stdout_config;

    /** Stderr transform config (NULL if no transforms) */
    qcontrol_exec_rw_config_t* stderr_config;
};

/**
 * Action result returned from exec callbacks.
 */
struct qcontrol_exec_action {
    qcontrol_exec_action_type_t type;
    union {
        /** errno value for BLOCK_ERRNO */
        int errno_val;
        /** Session config for SESSION */
        qcontrol_exec_session_t session;
        /** State pointer for STATE (no config, state only) */
        void* state;
    };
};

/* ============================================================================
 * Exec Action Convenience Macros
 * ============================================================================ */

/** Return PASS action (continue normally) */
#define QCONTROL_EXEC_PASS \
    ((qcontrol_exec_action_t){ .type = QCONTROL_EXEC_ACTION_PASS })

/** Return BLOCK action (reject with EACCES) */
#define QCONTROL_EXEC_BLOCK \
    ((qcontrol_exec_action_t){ .type = QCONTROL_EXEC_ACTION_BLOCK })

/** Return BLOCK_ERRNO action (reject with specific errno) */
#define QCONTROL_EXEC_BLOCK_WITH(e) \
    ((qcontrol_exec_action_t){ .type = QCONTROL_EXEC_ACTION_BLOCK_ERRNO, .errno_val = (e) })

/** Return STATE action (track state, no transforms) */
#define QCONTROL_EXEC_STATE(s) \
    ((qcontrol_exec_action_t){ .type = QCONTROL_EXEC_ACTION_STATE, .state = (s) })

/* ============================================================================
 * Exec Event Structures
 * ============================================================================ */

/**
 * Event passed to on_exec callback.
 * Represents a process being spawned (execve, posix_spawn, etc.)
 */
typedef struct {
    /** Executable path */
    const char* path;
    size_t path_len;

    /** Arguments (NULL-terminated) */
    const char* const* argv;
    size_t argc;

    /** Environment (NULL-terminated) */
    const char* const* envp;
    size_t envc;

    /** Working directory (may be NULL if not changed) */
    const char* cwd;
    size_t cwd_len;
} qcontrol_exec_event_t;

/**
 * Event passed to on_exec_stdin callback.
 * Data flowing to child process stdin.
 */
typedef struct {
    /** Child process ID */
    pid_t pid;

    /** Buffer containing data to write to stdin */
    const void* buf;

    /** Number of bytes */
    size_t count;
} qcontrol_exec_stdin_event_t;

/**
 * Event passed to on_exec_stdout callback.
 * Data flowing from child process stdout.
 */
typedef struct {
    /** Child process ID */
    pid_t pid;

    /** Buffer containing data read from stdout */
    void* buf;

    /** Number of bytes requested */
    size_t count;

    /** Bytes actually read, or -errno on error */
    ssize_t result;
} qcontrol_exec_stdout_event_t;

/**
 * Event passed to on_exec_stderr callback.
 * Data flowing from child process stderr.
 */
typedef struct {
    /** Child process ID */
    pid_t pid;

    /** Buffer containing data read from stderr */
    void* buf;

    /** Number of bytes requested */
    size_t count;

    /** Bytes actually read, or -errno on error */
    ssize_t result;
} qcontrol_exec_stderr_event_t;

/**
 * Event passed to on_exec_exit callback.
 * Child process has exited.
 */
typedef struct {
    /** Child process ID */
    pid_t pid;

    /** Exit code if exited normally (check exit_signal == 0) */
    int exit_code;

    /** Signal number if killed by signal (0 if normal exit) */
    int exit_signal;
} qcontrol_exec_exit_event_t;

/**
 * Exec context passed to transform functions.
 */
struct qcontrol_exec_ctx {
    /** Child process ID */
    pid_t pid;

    /** Executable path */
    const char* path;
    size_t path_len;

    /** Arguments (NULL-terminated) */
    const char* const* argv;
    size_t argc;
};

/* ============================================================================
 * Exec Callback Signatures
 * ============================================================================ */

/**
 * Exec callback - determines session configuration.
 *
 * Called before exec syscall executes. Return:
 * - PASS: no interception for this exec
 * - BLOCK: reject the exec (return error)
 * - SESSION: intercept with I/O config and/or modifications
 * - STATE: track state only, no transforms
 *
 * NOTE: Not yet implemented. Returns ENOSYS.
 */
typedef qcontrol_exec_action_t (*qcontrol_exec_fn)(
    qcontrol_exec_event_t* event
);

/**
 * Exec stdin callback - observe or block stdin writes.
 *
 * Called before data is written to child stdin. Can block but not modify.
 * Modification happens via session stdin_config transforms.
 *
 * NOTE: Not yet implemented. Returns ENOSYS.
 */
typedef qcontrol_exec_action_t (*qcontrol_exec_stdin_fn)(
    void* state,
    qcontrol_exec_stdin_event_t* event
);

/**
 * Exec stdout callback - observe or block stdout reads.
 *
 * Called after data is read from child stdout. Can block but not modify.
 * Modification happens via session stdout_config transforms.
 *
 * NOTE: Not yet implemented. Returns ENOSYS.
 */
typedef qcontrol_exec_action_t (*qcontrol_exec_stdout_fn)(
    void* state,
    qcontrol_exec_stdout_event_t* event
);

/**
 * Exec stderr callback - observe or block stderr reads.
 *
 * Called after data is read from child stderr. Can block but not modify.
 * Modification happens via session stderr_config transforms.
 *
 * NOTE: Not yet implemented. Returns ENOSYS.
 */
typedef qcontrol_exec_action_t (*qcontrol_exec_stderr_fn)(
    void* state,
    qcontrol_exec_stderr_event_t* event
);

/**
 * Exec exit callback - cleanup state.
 *
 * Called when child process exits.
 * Plugin is responsible for freeing state here.
 *
 * NOTE: Not yet implemented.
 */
typedef void (*qcontrol_exec_exit_fn)(
    void* state,
    qcontrol_exec_exit_event_t* event
);

#ifdef __cplusplus
}
#endif

#endif /* QCONTROL_EXEC_H */

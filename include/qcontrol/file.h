/**
 * @file qcontrol/file.h
 * @brief File operation types for qcontrol SDK
 *
 * Defines the session-based file plugin model where:
 * - Configuration happens per-file at open time (not globally)
 * - State flows automatically between operations on the same fd
 * - Declarative transforms (prefix, suffix, replace) require zero code
 * - The agent handles heavy lifting; SDKs are thin wrappers
 */

#ifndef QCONTROL_FILE_H
#define QCONTROL_FILE_H

#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * File Action Types
 * ============================================================================ */

/**
 * Action types returned by file operation callbacks.
 */
typedef enum {
    /** No interception, continue normally */
    QCONTROL_FILE_ACTION_PASS = 0,
    /** Block the operation with EACCES */
    QCONTROL_FILE_ACTION_BLOCK = 1,
    /** Block the operation with a specific errno */
    QCONTROL_FILE_ACTION_BLOCK_ERRNO = 2,
    /** Intercept with full session config */
    QCONTROL_FILE_ACTION_SESSION = 3,
    /** Track state only, no transforms */
    QCONTROL_FILE_ACTION_STATE = 4,
} qcontrol_file_action_type_t;

/* ============================================================================
 * File Pattern Replacement
 * ============================================================================ */

/**
 * Pattern for string replacement in transform pipeline.
 */
typedef struct {
    const char* needle;
    size_t needle_len;
    const char* replacement;
    size_t replacement_len;
} qcontrol_file_pattern_t;

/* ============================================================================
 * Forward Declarations
 * ============================================================================ */

typedef struct qcontrol_buffer qcontrol_buffer_t;
typedef struct qcontrol_file_ctx qcontrol_file_ctx_t;
typedef struct qcontrol_file_rw_config qcontrol_file_rw_config_t;
typedef struct qcontrol_file_session qcontrol_file_session_t;
typedef struct qcontrol_file_action qcontrol_file_action_t;

/* ============================================================================
 * File Transform Function Types
 * ============================================================================ */

/**
 * Transform function - called during read/write to modify buffer.
 *
 * @param state Plugin-defined state (from session)
 * @param ctx File context (fd, path, flags)
 * @param buf Buffer containing data to transform
 * @return Action indicating whether to continue or block
 */
typedef qcontrol_file_action_t (*qcontrol_file_transform_fn)(
    void* state,
    qcontrol_file_ctx_t* ctx,
    qcontrol_buffer_t* buf
);

/**
 * Dynamic prefix function - returns prefix to prepend.
 *
 * @param state Plugin-defined state
 * @param ctx File context
 * @param out_len Output parameter for prefix length
 * @return Prefix string (plugin-owned, must remain valid until close)
 */
typedef const char* (*qcontrol_file_prefix_fn)(
    void* state,
    qcontrol_file_ctx_t* ctx,
    size_t* out_len
);

/**
 * Dynamic suffix function - returns suffix to append.
 *
 * @param state Plugin-defined state
 * @param ctx File context
 * @param out_len Output parameter for suffix length
 * @return Suffix string (plugin-owned, must remain valid until close)
 */
typedef const char* (*qcontrol_file_suffix_fn)(
    void* state,
    qcontrol_file_ctx_t* ctx,
    size_t* out_len
);

/* ============================================================================
 * File Configuration Structures
 * ============================================================================ */

/**
 * Read/Write configuration for a file session.
 *
 * Transform order: prefix -> replace -> transform -> suffix
 */
struct qcontrol_file_rw_config {
    /** Static prefix to prepend (or NULL) */
    const char* prefix;
    size_t prefix_len;

    /** Static suffix to append (or NULL) */
    const char* suffix;
    size_t suffix_len;

    /** Dynamic prefix function (or NULL) */
    qcontrol_file_prefix_fn prefix_fn;

    /** Dynamic suffix function (or NULL) */
    qcontrol_file_suffix_fn suffix_fn;

    /** Pattern replacements array (or NULL) */
    const qcontrol_file_pattern_t* replace;
    size_t replace_count;

    /** Custom transform function (or NULL) */
    qcontrol_file_transform_fn transform;
};

/**
 * Session configuration for a file.
 * Returned from on_file_open to configure read/write behavior.
 */
struct qcontrol_file_session {
    /** Plugin-defined state (opaque, plugin owns memory) */
    void* state;

    /** Read transform config (NULL if no read transforms) */
    qcontrol_file_rw_config_t* read;

    /** Write transform config (NULL if no write transforms) */
    qcontrol_file_rw_config_t* write;
};

/**
 * Action result returned from file callbacks.
 */
struct qcontrol_file_action {
    qcontrol_file_action_type_t type;
    union {
        /** errno value for BLOCK_ERRNO */
        int errno_val;
        /** Session config for SESSION */
        qcontrol_file_session_t session;
        /** State pointer for STATE (no config, state only) */
        void* state;
    };
};

/* ============================================================================
 * File Action Convenience Macros
 * ============================================================================ */

/** Return PASS action (continue normally) */
#define QCONTROL_FILE_PASS \
    ((qcontrol_file_action_t){ .type = QCONTROL_FILE_ACTION_PASS })

/** Return BLOCK action (reject with EACCES) */
#define QCONTROL_FILE_BLOCK \
    ((qcontrol_file_action_t){ .type = QCONTROL_FILE_ACTION_BLOCK })

/** Return BLOCK_ERRNO action (reject with specific errno) */
#define QCONTROL_FILE_BLOCK_WITH(e) \
    ((qcontrol_file_action_t){ .type = QCONTROL_FILE_ACTION_BLOCK_ERRNO, .errno_val = (e) })

/** Return STATE action (track state, no transforms) */
#define QCONTROL_FILE_STATE(s) \
    ((qcontrol_file_action_t){ .type = QCONTROL_FILE_ACTION_STATE, .state = (s) })

/* ============================================================================
 * File Event Structures
 * ============================================================================ */

/**
 * Event passed to on_file_open callback.
 */
typedef struct {
    /** Path being opened */
    const char* path;
    size_t path_len;

    /** Open flags (O_RDONLY, O_WRONLY, etc.) */
    int flags;

    /** File mode for O_CREAT */
    unsigned int mode;

    /** Result: fd on success, -errno on failure */
    int result;
} qcontrol_file_open_event_t;

/**
 * Event passed to on_file_read callback.
 */
typedef struct {
    /** File descriptor */
    int fd;

    /** Buffer containing read data (read-only for observation) */
    void* buf;

    /** Number of bytes requested */
    size_t count;

    /** Bytes actually read, or -errno on error */
    ssize_t result;
} qcontrol_file_read_event_t;

/**
 * Event passed to on_file_write callback.
 */
typedef struct {
    /** File descriptor */
    int fd;

    /** Buffer containing data to write */
    const void* buf;

    /** Number of bytes to write */
    size_t count;

    /** Bytes actually written, or -errno on error */
    ssize_t result;
} qcontrol_file_write_event_t;

/**
 * Event passed to on_file_close callback.
 */
typedef struct {
    /** File descriptor */
    int fd;

    /** Result: 0 on success, -errno on failure */
    int result;
} qcontrol_file_close_event_t;

/**
 * File context passed to transform functions.
 */
struct qcontrol_file_ctx {
    /** File descriptor */
    int fd;

    /** Path (may be NULL if fd wasn't tracked from open) */
    const char* path;
    size_t path_len;

    /** Original open flags */
    int flags;
};

/* ============================================================================
 * File Callback Signatures
 * ============================================================================ */

/**
 * File open callback - determines session configuration.
 *
 * Called after open() syscall completes. Return:
 * - PASS: no interception for this file
 * - BLOCK: reject the open (close fd, return error)
 * - SESSION: intercept with read/write config
 * - STATE: track state only, no transforms
 */
typedef qcontrol_file_action_t (*qcontrol_file_open_fn)(
    qcontrol_file_open_event_t* event
);

/**
 * File read callback - observe or block reads.
 *
 * Called after read() syscall completes. Can block but not modify.
 * Modification happens via session read config transforms.
 */
typedef qcontrol_file_action_t (*qcontrol_file_read_fn)(
    void* state,
    qcontrol_file_read_event_t* event
);

/**
 * File write callback - observe or block writes.
 *
 * Called before write() syscall executes. Can block.
 * Modification happens via session write config transforms.
 */
typedef qcontrol_file_action_t (*qcontrol_file_write_fn)(
    void* state,
    qcontrol_file_write_event_t* event
);

/**
 * File close callback - cleanup state.
 *
 * Called after close() syscall completes.
 * Plugin is responsible for freeing state here.
 */
typedef void (*qcontrol_file_close_fn)(
    void* state,
    qcontrol_file_close_event_t* event
);

/* ============================================================================
 * Buffer Operations (implemented by agent)
 * ============================================================================ */

/**
 * Get buffer length.
 */
size_t qcontrol_buffer_len(const qcontrol_buffer_t* buf);

/**
 * Get pointer to buffer data.
 */
const char* qcontrol_buffer_data(const qcontrol_buffer_t* buf);

/**
 * Check if buffer contains needle.
 * @return 1 if found, 0 otherwise
 */
int qcontrol_buffer_contains(
    const qcontrol_buffer_t* buf,
    const char* needle,
    size_t needle_len
);

/**
 * Check if buffer starts with prefix.
 * @return 1 if true, 0 otherwise
 */
int qcontrol_buffer_starts_with(
    const qcontrol_buffer_t* buf,
    const char* prefix,
    size_t prefix_len
);

/**
 * Check if buffer ends with suffix.
 * @return 1 if true, 0 otherwise
 */
int qcontrol_buffer_ends_with(
    const qcontrol_buffer_t* buf,
    const char* suffix,
    size_t suffix_len
);

/**
 * Find index of needle in buffer.
 * @return Index if found, SIZE_MAX if not found
 */
size_t qcontrol_buffer_index_of(
    const qcontrol_buffer_t* buf,
    const char* needle,
    size_t needle_len
);

/**
 * Prepend data to buffer.
 */
void qcontrol_buffer_prepend(
    qcontrol_buffer_t* buf,
    const char* data,
    size_t len
);

/**
 * Append data to buffer.
 */
void qcontrol_buffer_append(
    qcontrol_buffer_t* buf,
    const char* data,
    size_t len
);

/**
 * Replace first occurrence of needle with replacement.
 * @return 1 if replaced, 0 if not found
 */
int qcontrol_buffer_replace(
    qcontrol_buffer_t* buf,
    const char* needle,
    size_t needle_len,
    const char* replacement,
    size_t replacement_len
);

/**
 * Replace all occurrences of needle with replacement.
 * @return Number of replacements made
 */
size_t qcontrol_buffer_replace_all(
    qcontrol_buffer_t* buf,
    const char* needle,
    size_t needle_len,
    const char* replacement,
    size_t replacement_len
);

/**
 * Remove first occurrence of needle.
 * @return 1 if removed, 0 if not found
 */
int qcontrol_buffer_remove(
    qcontrol_buffer_t* buf,
    const char* needle,
    size_t needle_len
);

/**
 * Remove all occurrences of needle.
 * @return Number of removals
 */
size_t qcontrol_buffer_remove_all(
    qcontrol_buffer_t* buf,
    const char* needle,
    size_t needle_len
);

/**
 * Clear buffer contents.
 */
void qcontrol_buffer_clear(qcontrol_buffer_t* buf);

/**
 * Set buffer contents to new data.
 */
void qcontrol_buffer_set(
    qcontrol_buffer_t* buf,
    const char* data,
    size_t len
);

/**
 * Insert data at position.
 */
void qcontrol_buffer_insert_at(
    qcontrol_buffer_t* buf,
    size_t pos,
    const char* data,
    size_t len
);

/**
 * Remove range from buffer.
 */
void qcontrol_buffer_remove_range(
    qcontrol_buffer_t* buf,
    size_t start,
    size_t end
);

#ifdef __cplusplus
}
#endif

#endif /* QCONTROL_FILE_H */

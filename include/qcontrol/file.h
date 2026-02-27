/**
 * @file qcontrol/file.h
 * @brief File operation filter API for qcontrol SDK
 *
 * Provides filter callbacks for file operations: open, read, write, close.
 * Filters use an Envoy-inspired pattern where each filter can:
 * - CONTINUE: pass to next filter unchanged
 * - MODIFY: apply changes and continue
 * - BLOCK: abort operation (first BLOCK wins)
 */

#ifndef QCONTROL_FILE_H
#define QCONTROL_FILE_H

#include "common.h"
#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * Context Structures
 * ============================================================================ */

/**
 * Context for open() filter callbacks.
 */
typedef struct {
    /** Current phase (ENTER or LEAVE) */
    qcontrol_phase_t phase;

    /** Input path being opened */
    const char* path;

    /** Buffer for modified path (ENTER phase only, size: QCONTROL_MAX_PATH) */
    char* path_out;

    /** Open flags (O_RDONLY, O_WRONLY, etc.) */
    int flags;

    /** File mode for O_CREAT */
    unsigned int mode;

    /** Result fd (LEAVE phase) or errno negated on error */
    int result;

    /** User data passed during registration */
    void* user_data;
} qcontrol_file_open_ctx_t;

/**
 * Context for read() filter callbacks.
 */
typedef struct {
    /** Current phase (ENTER or LEAVE) */
    qcontrol_phase_t phase;

    /** File descriptor being read */
    int fd;

    /** Buffer for read data */
    void* buf;

    /** Number of bytes requested */
    size_t count;

    /** Bytes read (LEAVE phase) or errno negated on error */
    ssize_t result;

    /** User data passed during registration */
    void* user_data;
} qcontrol_file_read_ctx_t;

/**
 * Context for write() filter callbacks.
 */
typedef struct {
    /** Current phase (ENTER or LEAVE) */
    qcontrol_phase_t phase;

    /** File descriptor being written */
    int fd;

    /** Buffer containing data to write */
    const void* buf;

    /** Number of bytes to write */
    size_t count;

    /** Bytes written (LEAVE phase) or errno negated on error */
    ssize_t result;

    /** User data passed during registration */
    void* user_data;
} qcontrol_file_write_ctx_t;

/**
 * Context for close() filter callbacks.
 */
typedef struct {
    /** Current phase (ENTER or LEAVE) */
    qcontrol_phase_t phase;

    /** File descriptor being closed */
    int fd;

    /** Result (LEAVE phase): 0 on success, errno negated on error */
    int result;

    /** User data passed during registration */
    void* user_data;
} qcontrol_file_close_ctx_t;

/* ============================================================================
 * Filter Callback Types
 * ============================================================================ */

/**
 * Filter callback for open() operations.
 *
 * @param ctx Context with operation parameters and results
 * @return Status code indicating how to proceed
 */
typedef qcontrol_status_t (*qcontrol_file_open_filter_fn)(qcontrol_file_open_ctx_t* ctx);

/**
 * Filter callback for read() operations.
 *
 * @param ctx Context with operation parameters and results
 * @return Status code indicating how to proceed
 */
typedef qcontrol_status_t (*qcontrol_file_read_filter_fn)(qcontrol_file_read_ctx_t* ctx);

/**
 * Filter callback for write() operations.
 *
 * @param ctx Context with operation parameters and results
 * @return Status code indicating how to proceed
 */
typedef qcontrol_status_t (*qcontrol_file_write_filter_fn)(qcontrol_file_write_ctx_t* ctx);

/**
 * Filter callback for close() operations.
 *
 * @param ctx Context with operation parameters and results
 * @return Status code indicating how to proceed
 */
typedef qcontrol_status_t (*qcontrol_file_close_filter_fn)(qcontrol_file_close_ctx_t* ctx);

/* ============================================================================
 * Registration Functions
 * ============================================================================ */

/**
 * Register a filter for open() operations.
 *
 * @param name Filter name for debugging (copied internally)
 * @param on_enter Callback for ENTER phase (may be NULL)
 * @param on_leave Callback for LEAVE phase (may be NULL)
 * @param user_data User data passed to callbacks
 * @return Handle for unregistration, or QCONTROL_INVALID_HANDLE on error
 */
qcontrol_filter_handle_t qcontrol_register_file_open_filter(
    const char* name,
    qcontrol_file_open_filter_fn on_enter,
    qcontrol_file_open_filter_fn on_leave,
    void* user_data
);

/**
 * Register a filter for read() operations.
 *
 * @param name Filter name for debugging (copied internally)
 * @param on_enter Callback for ENTER phase (may be NULL)
 * @param on_leave Callback for LEAVE phase (may be NULL)
 * @param user_data User data passed to callbacks
 * @return Handle for unregistration, or QCONTROL_INVALID_HANDLE on error
 */
qcontrol_filter_handle_t qcontrol_register_file_read_filter(
    const char* name,
    qcontrol_file_read_filter_fn on_enter,
    qcontrol_file_read_filter_fn on_leave,
    void* user_data
);

/**
 * Register a filter for write() operations.
 *
 * @param name Filter name for debugging (copied internally)
 * @param on_enter Callback for ENTER phase (may be NULL)
 * @param on_leave Callback for LEAVE phase (may be NULL)
 * @param user_data User data passed to callbacks
 * @return Handle for unregistration, or QCONTROL_INVALID_HANDLE on error
 */
qcontrol_filter_handle_t qcontrol_register_file_write_filter(
    const char* name,
    qcontrol_file_write_filter_fn on_enter,
    qcontrol_file_write_filter_fn on_leave,
    void* user_data
);

/**
 * Register a filter for close() operations.
 *
 * @param name Filter name for debugging (copied internally)
 * @param on_enter Callback for ENTER phase (may be NULL)
 * @param on_leave Callback for LEAVE phase (may be NULL)
 * @param user_data User data passed to callbacks
 * @return Handle for unregistration, or QCONTROL_INVALID_HANDLE on error
 */
qcontrol_filter_handle_t qcontrol_register_file_close_filter(
    const char* name,
    qcontrol_file_close_filter_fn on_enter,
    qcontrol_file_close_filter_fn on_leave,
    void* user_data
);

/**
 * Unregister a previously registered filter.
 *
 * @param handle Handle returned from registration
 * @return 0 on success, -1 if handle not found
 */
int qcontrol_unregister_filter(qcontrol_filter_handle_t handle);

#ifdef __cplusplus
}
#endif

#endif /* QCONTROL_FILE_H */

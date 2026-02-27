/**
 * @file qcontrol/common.h
 * @brief Core types, status codes, and error codes for qcontrol SDK
 */

#ifndef QCONTROL_COMMON_H
#define QCONTROL_COMMON_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Filter status codes returned by filter callbacks.
 * First BLOCK wins and short-circuits the filter chain.
 */
typedef enum {
    /** Continue to next filter in chain */
    QCONTROL_STATUS_CONTINUE = 0,
    /** Continue but apply modifications from this filter */
    QCONTROL_STATUS_MODIFY = 1,
    /** Block the operation (returns -EACCES) */
    QCONTROL_STATUS_BLOCK = 2
} qcontrol_status_t;

/**
 * Operation phase for filter callbacks.
 */
typedef enum {
    /** Before the operation executes */
    QCONTROL_PHASE_ENTER = 0,
    /** After the operation completes */
    QCONTROL_PHASE_LEAVE = 1
} qcontrol_phase_t;

/**
 * Handle for registered filters, used for unregistration.
 */
typedef uint64_t qcontrol_filter_handle_t;

/**
 * Invalid filter handle sentinel value.
 */
#define QCONTROL_INVALID_HANDLE ((qcontrol_filter_handle_t)0)

/**
 * Maximum path length for file operations.
 */
#define QCONTROL_MAX_PATH 4096

#ifdef __cplusplus
}
#endif

#endif /* QCONTROL_COMMON_H */

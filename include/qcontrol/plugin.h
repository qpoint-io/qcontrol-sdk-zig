/**
 * @file qcontrol/plugin.h
 * @brief Plugin descriptor for qcontrol SDK
 *
 * Defines the plugin descriptor structure that plugins export.
 * Includes operation-specific headers for the callback types.
 */

#ifndef QCONTROL_PLUGIN_H
#define QCONTROL_PLUGIN_H

#include "common.h"
#include "file.h"
#include "exec.h"
#include "net.h"

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * Plugin Descriptor
 * ============================================================================ */

/**
 * Plugin descriptor.
 *
 * Single plugin, multiple operation types. Export as const qcontrol_plugin.
 *
 * Example:
 * @code
 * const qcontrol_plugin_t qcontrol_plugin = {
 *     .version = QCONTROL_PLUGIN_VERSION,
 *     .name = "my-plugin",
 *     .on_file_open = my_file_open,
 *     .on_file_read = my_file_read,
 *     .on_file_close = my_file_close,
 * };
 * @endcode
 */
/**
 * Plugin init callback.
 * Called after plugin is loaded. Return 0 on success, non-zero on failure.
 */
typedef int (*qcontrol_plugin_init_fn)(void);

/**
 * Plugin cleanup callback.
 * Called before plugin is unloaded.
 */
typedef void (*qcontrol_plugin_cleanup_fn)(void);

typedef struct {
    /** Must be QCONTROL_PLUGIN_VERSION */
    uint32_t version;

    /** Plugin name for debugging */
    const char* name;

    /* === LIFECYCLE (optional) === */
    /** Called after plugin load, return 0 on success */
    qcontrol_plugin_init_fn on_init;
    /** Called before plugin unload */
    qcontrol_plugin_cleanup_fn on_cleanup;

    /* === FILE OPERATIONS (all optional) === */
    qcontrol_file_open_fn on_file_open;
    qcontrol_file_read_fn on_file_read;
    qcontrol_file_write_fn on_file_write;
    qcontrol_file_close_fn on_file_close;

    /* === EXEC OPERATIONS (all optional, v1 spec - not yet implemented) === */
    qcontrol_exec_fn on_exec;
    qcontrol_exec_stdin_fn on_exec_stdin;
    qcontrol_exec_stdout_fn on_exec_stdout;
    qcontrol_exec_stderr_fn on_exec_stderr;
    qcontrol_exec_exit_fn on_exec_exit;

    /* === NETWORK OPERATIONS (all optional, v1 spec - not yet implemented) === */
    qcontrol_net_connect_fn on_net_connect;
    qcontrol_net_accept_fn on_net_accept;
    qcontrol_net_tls_fn on_net_tls;
    qcontrol_net_domain_fn on_net_domain;
    qcontrol_net_protocol_fn on_net_protocol;
    qcontrol_net_send_fn on_net_send;
    qcontrol_net_recv_fn on_net_recv;
    qcontrol_net_close_fn on_net_close;

} qcontrol_plugin_t;

/**
 * Plugins must export this symbol.
 */
extern const qcontrol_plugin_t qcontrol_plugin;

#ifdef __cplusplus
}
#endif

#endif /* QCONTROL_PLUGIN_H */

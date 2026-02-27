/**
 * @file qcontrol.h
 * @brief Main include file for qcontrol SDK
 *
 * Include this header to access the complete qcontrol SDK API.
 *
 * ## Plugin Development
 *
 * Plugins are shared libraries that export a qcontrol_plugin_init() function.
 * This function is called when the plugin is loaded and should register
 * any desired filters.
 *
 * Example plugin:
 * @code
 * #include <qcontrol.h>
 * #include <stdio.h>
 *
 * static qcontrol_status_t on_file_open_leave(qcontrol_file_open_ctx_t* ctx) {
 *     fprintf(stderr, "[log] open(%s) = %d\n", ctx->path, ctx->result);
 *     return QCONTROL_STATUS_CONTINUE;
 * }
 *
 * int qcontrol_plugin_init(void) {
 *     qcontrol_register_file_open_filter("logger", NULL, on_file_open_leave, NULL);
 *     return 0;
 * }
 * @endcode
 *
 * ## Loading Plugins
 *
 * Set the QCONTROL_PLUGINS environment variable to a comma-separated list
 * of plugin paths:
 *
 * @code
 * QCONTROL_PLUGINS=./plugin1.so,./plugin2.so qcontrol wrap -- ./target
 * @endcode
 */

#ifndef QCONTROL_H
#define QCONTROL_H

#include "qcontrol/common.h"
#include "qcontrol/file.h"

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * Plugin Interface
 * ============================================================================ */

/**
 * Plugin initialization function.
 *
 * Every plugin MUST export this function. It is called when the plugin
 * is loaded and should register any filters the plugin provides.
 *
 * @return 0 on success, non-zero on failure
 */
int qcontrol_plugin_init(void);

/**
 * Plugin cleanup function (optional).
 *
 * If exported, this function is called before the plugin is unloaded.
 * Plugins should unregister filters and free resources here.
 */
void qcontrol_plugin_cleanup(void);

#ifdef __cplusplus
}
#endif

#endif /* QCONTROL_H */

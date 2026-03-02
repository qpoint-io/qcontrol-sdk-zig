/**
 * @file qcontrol.h
 * @brief Main include file for qcontrol SDK
 *
 * Include this header to access the complete qcontrol SDK API.
 *
 * ## Plugin Development
 *
 * Plugins are shared libraries that export a qcontrol_plugin descriptor.
 * The descriptor is a const struct that defines callbacks for file operations.
 *
 * Example plugin:
 * @code
 * #include <qcontrol.h>
 * #include <stdio.h>
 *
 * static qcontrol_file_action_t on_file_open(qcontrol_file_open_event_t* event) {
 *     fprintf(stderr, "[log] open(%s) = %d\n", event->path, event->result);
 *     return QCONTROL_FILE_PASS;
 * }
 *
 * const qcontrol_plugin_t qcontrol_plugin = {
 *     .version = QCONTROL_PLUGIN_VERSION,
 *     .name = "logger",
 *     .on_file_open = on_file_open,
 * };
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
 *
 * Or bundle plugins into the agent for distribution:
 *
 * @code
 * qcontrol bundle --config bundle.toml -o my-bundle.so
 * qcontrol wrap --bundle my-bundle.so -- ./target
 * @endcode
 */

#ifndef QCONTROL_H
#define QCONTROL_H

#include "qcontrol/common.h"
#include "qcontrol/file.h"
#include "qcontrol/plugin.h"

#endif /* QCONTROL_H */

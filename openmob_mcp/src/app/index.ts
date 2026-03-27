#!/usr/bin/env node

import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { createServer } from "./create-server.js";
import { createHubClient } from "../mcp/common/hub-client.js";
import { registerAllTools } from "./register-tools.js";

const HELP_TEXT = `openmob-mcp — OpenMob MCP Server for mobile device automation

Usage:
  openmob-mcp              Start the MCP server on stdio
  openmob-mcp --help       Show this help message
  openmob-mcp --version    Show version

Environment variables:
  OPENMOB_HUB_URL    Full Hub API URL (e.g. http://127.0.0.1:8686/api/v1)
  OPENMOB_HUB_PORT   Hub port number (default: auto-detect 8686-8690)

Resources (3):
  openmob://guide          Step-by-step usage guide
  openmob://tools          Full tool reference with descriptions
  openmob://status         Live Hub and device connection status

Tools (38):
  Device Info:
    list_devices             See all connected devices
    get_screenshot           Capture device screen as image
    get_ui_tree              Get all UI elements with indices
    get_screen_size          Get screen width/height in pixels
    get_orientation          Check portrait/landscape mode
    find_element             Search elements by text/class/resource ID
    list_apps                List installed apps
    get_current_activity     See foreground app/screen
    get_device_logs          Get logcat output (filterable)
    get_notifications        Read notification bar
    save_screenshot          Save screenshot to file
    wait_for_element         Wait for element to appear
    pair_wireless            Pair Android 11+ wirelessly
    connect_wireless         Connect to device over WiFi

  Touch & Input:
    tap                      Tap by element index or coordinates
    double_tap               Double-tap for zoom/select
    long_press               Press and hold
    swipe                    Scroll or swipe by direction/coords
    type_text                Type into focused input field
    press_button             Press hardware button (Back/Home/etc)
    go_home                  Go to home screen

  App Management:
    launch_app               Open app by package/bundle ID
    terminate_app            Force-close a running app
    install_app              Install APK from file path
    uninstall_app            Remove app from device
    open_url                 Open URL or deep link
    clear_app_data           Wipe app data (fresh install)
    grant_permissions        Auto-grant all runtime permissions

  Device Settings:
    set_rotation             Rotate screen orientation
    toggle_wifi              Turn WiFi on/off
    toggle_airplane_mode     Turn airplane mode on/off

  Screen Recording:
    start_recording          Begin recording device screen
    stop_recording           Stop recording, save file
    get_recording            Get recording details/events
    list_recordings          List all recordings

  Testing:
    run_test                 Run multi-step test with assertions

Each tool is also available with a mobile_ prefix (e.g., mobile_tap).

The server communicates via stdio using the Model Context Protocol (MCP).
It connects to a running OpenMob Hub to control mobile devices.
`;

function printHelp(): void {
  process.stdout.write(HELP_TEXT);
}

function printVersion(): void {
  process.stdout.write("openmob-mcp 0.0.10\n");
}

// Handle --help / -h / --version before starting the server
const args = process.argv.slice(2);
if (args.includes("--help") || args.includes("-h")) {
  printHelp();
  process.exit(0);
}
if (args.includes("--version") || args.includes("-v")) {
  printVersion();
  process.exit(0);
}

async function main() {
  const hub = await createHubClient();
  console.error(`[openmob-mcp] Hub URL: ${hub.hubUrl}`);

  const server = createServer();
  registerAllTools(server, hub);

  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("[openmob-mcp] MCP Server running on stdio");
}

main().catch((error) => {
  console.error("[openmob-mcp] Fatal error:", error);
  process.exit(1);
});

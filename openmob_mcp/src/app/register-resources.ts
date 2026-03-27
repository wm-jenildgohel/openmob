import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { HubClient } from "../mcp/common/hub-client.js";
import type { Device } from "../types/index.js";

const GUIDE_TEXT = `# OpenMob Usage Guide

OpenMob lets you see and control Android/iOS devices from an AI agent. Here is how to use it step by step.

## Step 1: Check Connected Devices
Call \`list_devices\` (no parameters needed). This returns all connected devices with their device_id, model name, OS, screen size, battery level, and connection type (USB/WiFi/emulator). You need the device_id for every other tool.

## Step 2: See What's On Screen
Call \`get_screenshot\` with the device_id. This returns the actual screen image so you can see exactly what the user sees. Use this to understand the current state before taking action.

## Step 3: Read the UI Elements
Call \`get_ui_tree\` with the device_id. This returns every button, text field, label, image, and other element on screen, each with an index number. Use \`text_filter\` to search for specific elements (e.g., text_filter="Login").

## Step 4: Interact With the Device
- **Tap an element**: Call \`tap\` with device_id and the element's index number from get_ui_tree. This is the most reliable way to interact.
- **Tap by coordinates**: Call \`tap\` with device_id, x, and y. Use this when elements overlap or indices don't work.
- **Type text**: First tap an input field to focus it, then call \`type_text\` with the text. Set submit=true to press Enter after.
- **Scroll**: Call \`swipe\` with direction="up" to scroll down and see more content. "down" scrolls up.
- **Go back**: Call \`press_button\` with key_code=4 (Back button).
- **Go home**: Call \`go_home\` to return to the home screen.

## Step 5: Verify the Result
After every action, call \`get_screenshot\` to confirm it worked. If the UI changed as expected, continue. If not, try again or use a different approach.

## Common Workflows

### Open an app and navigate
1. \`list_devices\` -> get device_id
2. \`launch_app\` with the package name (e.g., "com.android.settings")
3. \`get_screenshot\` to see the app
4. \`get_ui_tree\` to find elements
5. \`tap\` the element you want
6. \`get_screenshot\` to verify

### Fill in a form
1. \`get_ui_tree\` with text_filter to find the input field
2. \`tap\` the field's index to focus it
3. \`type_text\` with the text to enter
4. Repeat for each field
5. \`tap\` the submit button

### Debug a crash
1. \`launch_app\` to open the app
2. Reproduce the issue with tap/swipe/type_text
3. \`get_device_logs\` with tag or level filter to see crash logs
4. \`get_screenshot\` to capture the error state

### Record a test flow
1. \`start_recording\` to begin capturing video
2. Perform your actions (tap, type, swipe, etc.)
3. \`stop_recording\` to save the video with timestamps
`;

const TOOLS_TEXT = `# OpenMob Tool Reference

## Device Info Tools
- **list_devices** — See all connected mobile devices with name, model, OS, screen size, battery, connection type. Use the device_id from this in all other tools.
- **get_screenshot** — Capture the current screen as an image. Use after every action to verify results.
- **get_ui_tree** — Get all UI elements (buttons, fields, labels) with index numbers for tapping. Supports text_filter and visible_only.
- **get_screen_size** — Get screen dimensions in pixels (width x height).
- **get_orientation** — Check if device is portrait or landscape.
- **find_element** — Search for elements by text, class name, or resource ID. More powerful than get_ui_tree's text_filter.
- **list_apps** — List installed apps. Use third_party_only to filter out system apps.
- **get_current_activity** — See which app/screen is in the foreground.
- **get_device_logs** — Get logcat output. Filter by tag, level, or line count. Use for debugging.
- **get_notifications** — Read all current notifications from the notification bar.

## Touch & Input Tools
- **tap** — Single tap by element index (from get_ui_tree) or x,y coordinates. The primary way to interact with the UI.
- **double_tap** — Double-tap for zooming or text selection. Uses index or coordinates.
- **long_press** — Press and hold for context menus or drag mode. Customizable duration.
- **swipe** — Scroll or swipe. direction="up" scrolls down. Also supports exact x1,y1 to x2,y2 coordinates.
- **type_text** — Type into the focused input field. Set submit=true to press Enter after.
- **press_button** — Press hardware buttons: Back(4), Home(3), Volume Up(24), Volume Down(25), Power(26), Enter(66), Menu(82), Recent Apps(187).
- **go_home** — Go to the home screen.

## App Management Tools
- **launch_app** — Open an app by package name (Android) or bundle ID (iOS).
- **terminate_app** — Force-close a running app.
- **install_app** — Install an APK from a local file path.
- **uninstall_app** — Remove an app from the device.
- **open_url** — Open a URL in the browser or a deep link in the handling app.
- **clear_app_data** — Wipe all app data (like a fresh install).
- **grant_permissions** — Auto-grant all runtime permissions for an app.

## Device Settings Tools
- **set_rotation** — Rotate screen: 0=portrait, 1=landscape left, 2=reverse portrait, 3=landscape right.
- **toggle_wifi** — Turn WiFi on or off.
- **toggle_airplane_mode** — Turn airplane mode on or off.
- **save_screenshot** — Save a screenshot to a file path on the host computer.
- **wait_for_element** — Wait until a specific element appears on screen (with timeout).

## Wireless Setup Tools
- **pair_wireless** — Pair with an Android 11+ device wirelessly using the pairing code.
- **connect_wireless** — Connect to a device over WiFi after pairing.

## Screen Recording Tools
- **start_recording** — Begin recording the device screen (video). Supports MKV/MP4, audio, custom bitrate.
- **stop_recording** — Stop recording and save the file. Returns path, duration, and size.
- **get_recording** — Get details about a specific recording including timestamped events.
- **list_recordings** — List all recordings, optionally filtered by device.

## Testing Tools
- **run_test** — Run a multi-step test with actions and assertions. Returns pass/fail with timing and failure screenshots.
`;

export function registerResources(server: McpServer, hub: HubClient): void {
  // openmob://guide — Full usage guide
  server.registerResource(
    "guide",
    "openmob://guide",
    {
      description: "Step-by-step guide for using OpenMob to control mobile devices. Read this first to understand the workflow: list devices, take screenshots, read UI elements, tap/type/swipe, and verify results.",
      mimeType: "text/markdown",
    },
    async () => ({
      contents: [
        {
          uri: "openmob://guide",
          text: GUIDE_TEXT,
          mimeType: "text/markdown",
        },
      ],
    }),
  );

  // openmob://tools — Tool reference
  server.registerResource(
    "tools",
    "openmob://tools",
    {
      description: "Complete reference of all OpenMob tools organized by category (device info, touch actions, app management, recording, testing) with descriptions of what each tool does and when to use it.",
      mimeType: "text/markdown",
    },
    async () => ({
      contents: [
        {
          uri: "openmob://tools",
          text: TOOLS_TEXT,
          mimeType: "text/markdown",
        },
      ],
    }),
  );

  // openmob://status — Live Hub status
  server.registerResource(
    "status",
    "openmob://status",
    {
      description: "Check if the OpenMob Hub is running and see connected devices. Read this to verify the system is ready before using device tools.",
      mimeType: "application/json",
    },
    async () => {
      let hubStatus: "connected" | "unreachable";
      let devices: Device[] = [];
      let hubUrl = hub.hubUrl;

      try {
        devices = await hub.get<Device[]>("/devices/");
        hubStatus = "connected";
      } catch {
        hubStatus = "unreachable";
      }

      const status = {
        hub: {
          url: hubUrl,
          status: hubStatus,
        },
        devices: {
          count: devices.length,
          list: devices.map((d) => ({
            id: d.id,
            model: d.model,
            platform: d.platform,
            connectionType: d.connectionType,
          })),
        },
        summary:
          hubStatus === "unreachable"
            ? `Hub at ${hubUrl} is not reachable. Start the OpenMob Hub first.`
            : devices.length === 0
              ? `Hub is running at ${hubUrl} but no devices are connected. Connect a device via USB or start an emulator.`
              : `Hub is running at ${hubUrl} with ${devices.length} device(s): ${devices.map((d) => d.model).join(", ")}.`,
      };

      return {
        contents: [
          {
            uri: "openmob://status",
            text: JSON.stringify(status, null, 2),
            mimeType: "application/json",
          },
        ],
      };
    },
  );
}

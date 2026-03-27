import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";

const INSTRUCTIONS = `OpenMob gives you control over Android and iOS mobile devices. You can see what's on a device screen, tap buttons, type text, swipe, launch apps, and more — all programmatically.

## Quick Start
1. Call list_devices to see connected devices and get a device_id.
2. Call get_screenshot to see what's currently on screen.
3. Call get_ui_tree to get all tappable elements with index numbers.
4. Call tap with an element index to interact with the UI.
5. Call get_screenshot again to verify the result.

## Key Concepts
- Every tool that interacts with a device requires a device_id parameter. Get it from list_devices.
- Use get_ui_tree to discover element indices, then pass those indices to tap, double_tap, or long_press.
- After performing any action (tap, swipe, type_text), take a screenshot to verify it worked.
- Use swipe with direction='up' to scroll down and reveal more content.

## Available Tool Categories
- **Device Info**: list_devices, get_screenshot, get_ui_tree, get_screen_size, get_orientation, find_element, list_apps, get_current_activity, get_device_logs, get_notifications
- **Touch Actions**: tap, double_tap, long_press, swipe
- **Input**: type_text, press_button, go_home
- **App Management**: launch_app, terminate_app, install_app, uninstall_app, open_url, clear_app_data, grant_permissions
- **Device Settings**: set_rotation, toggle_wifi, toggle_airplane_mode, save_screenshot, wait_for_element
- **Wireless Setup**: pair_wireless, connect_wireless
- **Screen Recording**: start_recording, stop_recording, get_recording, list_recordings
- **Testing**: run_test

## Resources
Read openmob://guide for a detailed step-by-step usage guide.
Read openmob://tools for a full tool reference with descriptions.
Read openmob://status to check if the Hub is running and see connected devices.

## Tips
- Always start with list_devices to confirm a device is connected.
- Prefer element indices over x,y coordinates — they are more reliable.
- If an element is not visible, swipe to scroll before trying to interact with it.
- Use wait_for_element after navigation to wait for the next screen to load.
- Use start_recording before complex test flows to capture video evidence.`;

export function createServer(): McpServer {
  return new McpServer(
    {
      name: "openmob",
      version: "0.0.10",
    },
    {
      instructions: INSTRUCTIONS,
    },
  );
}

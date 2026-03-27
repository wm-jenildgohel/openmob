import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { HubClient } from "../../common/hub-client.js";
import { deviceIdSchema, packageSchema } from "../../common/schemas.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import { registerToolDual } from "../../common/dual-register.js";
import type { ActionResult } from "../../../types/index.js";

export function registerListApps(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "list_apps",
    {
      description:
        "List all installed apps on the device. Returns package names (Android) or bundle IDs (iOS). " +
        "Set third_party_only=true (default) to see only user-installed apps, excluding system apps. " +
        "Use this to find the correct package name for launch_app, terminate_app, or clear_app_data. " +
        "Returns: Array of package names and count. " +
        "Related: launch_app (open an app), get_current_activity (see which app is in foreground).",
      inputSchema: {
        device_id: deviceIdSchema,
        third_party_only: z.boolean().optional().describe("Only show user-installed apps, not system apps (default: true)"),
      },
    },
    async ({ device_id, third_party_only }) => {
      try {
        const params = third_party_only === false ? "?third_party=false" : "";
        const result = await hub.get<ActionResult>(`/devices/${device_id}/apps${params}`);
        const data = result as unknown as { data?: { packages?: string[]; count?: number } };
        const count = data?.data?.count ?? 0;
        return createTextResponse(result, `Found ${count} installed app${count !== 1 ? "s" : ""}`);
      } catch (error) {
        return createErrorResponse(error, "Could not list apps");
      }
    }
  );
}

export function registerGetCurrentActivity(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "get_current_activity",
    {
      description:
        "See which app and activity/screen is currently in the foreground. " +
        "Returns the package name and activity class of the active app. " +
        "Use this to confirm an app launched correctly or to identify what's running before taking action. " +
        "Related: launch_app (open a different app), terminate_app (close the current app), get_screenshot (see the screen).",
      inputSchema: {
        device_id: deviceIdSchema,
      },
    },
    async ({ device_id }) => {
      try {
        const result = await hub.get<ActionResult>(`/devices/${device_id}/current-activity`);
        const data = result as unknown as { data?: { package?: string; activity?: string } };
        const pkg = data?.data?.package ?? "unknown";
        return createTextResponse(result, `Current app: ${pkg}`);
      } catch (error) {
        return createErrorResponse(error, "Could not determine current app");
      }
    }
  );
}

export function registerClearAppData(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "clear_app_data",
    {
      description:
        "Clear all data for an app — resets it to a fresh-install state. Removes saved settings, login credentials, cache, databases, and shared preferences. " +
        "Use this before testing to ensure a clean starting state, or to force re-login. " +
        "The app will NOT be uninstalled, just its data wiped. " +
        "Related: uninstall_app (remove entirely), launch_app (open the reset app), grant_permissions (re-grant permissions after reset).",
      inputSchema: {
        device_id: deviceIdSchema,
        package: packageSchema,
      },
    },
    async ({ device_id, package: pkg }) => {
      try {
        const result = await hub.post<ActionResult>(`/devices/${device_id}/clear-data`, { package: pkg });
        return createTextResponse(result, `Cleared all data for ${pkg.split(".").pop()}`);
      } catch (error) {
        return createErrorResponse(error, "Could not clear app data");
      }
    }
  );
}

export function registerGetLogs(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "get_device_logs",
    {
      description:
        "Get recent device logs (Android logcat). Filter by app tag, minimum log level, or number of lines to return. " +
        "Use this to debug crashes, find error messages, or monitor app behavior after performing actions. " +
        "Returns: Array of log lines with timestamps and tags. " +
        "Related: get_screenshot (see error dialogs visually), get_current_activity (check which app crashed).",
      inputSchema: {
        device_id: deviceIdSchema,
        lines: z.number().optional().describe("Number of recent log lines to return (default: 100)"),
        tag: z.string().optional().describe("Filter by app tag (e.g., 'MyApp', 'AndroidRuntime')"),
        level: z.enum(["verbose", "debug", "info", "warning", "error"]).optional().describe("Minimum log level"),
      },
    },
    async ({ device_id, lines, tag, level }) => {
      try {
        const params = new URLSearchParams();
        if (lines) params.set("lines", String(lines));
        if (tag) params.set("tag", tag);
        if (level) params.set("level", level);
        const qs = params.toString() ? `?${params.toString()}` : "";
        const result = await hub.get<ActionResult>(`/devices/${device_id}/logcat${qs}`);
        const data = result as unknown as { data?: { count?: number } };
        return createTextResponse(result, `Retrieved ${data?.data?.count ?? 0} log lines`);
      } catch (error) {
        return createErrorResponse(error, "Could not get device logs");
      }
    }
  );
}

export function registerWaitForElement(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "wait_for_element",
    {
      description:
        "Wait until a specific UI element appears on screen, polling repeatedly until found or timeout. " +
        "Use this after navigation, page loads, or animations — instead of arbitrary delays. " +
        "Search by visible text or resource ID. Default timeout is 10 seconds. " +
        "Returns: The found element's index (for tapping) and how long it waited. Returns failure if element never appeared. " +
        "Related: find_element (search without waiting), tap (interact with the found element), get_ui_tree (see all elements).",
      inputSchema: {
        device_id: deviceIdSchema,
        text: z.string().optional().describe("Text the element should contain (e.g., 'Login', 'Welcome')"),
        resource_id: z.string().optional().describe("Resource ID to match (e.g., 'com.app:id/submit_btn')"),
        timeout_ms: z.number().optional().describe("Max time to wait in milliseconds (default: 10000)"),
      },
    },
    async ({ device_id, text, resource_id, timeout_ms }) => {
      try {
        const result = await hub.post<ActionResult>(`/devices/${device_id}/wait-for-element`, {
          text, resource_id, timeout_ms: timeout_ms ?? 10000,
        });
        const data = result as unknown as { data?: { found?: boolean; index?: number; waitedMs?: number } };
        if (data?.data?.found) {
          return createTextResponse(result, `Found element "${text || resource_id}" (index #${data.data.index}) after ${data.data.waitedMs}ms`);
        }
        return createTextResponse(result, `Element not found after ${timeout_ms ?? 10000}ms`);
      } catch (error) {
        return createErrorResponse(error, "Element did not appear in time");
      }
    }
  );
}

export function registerSetRotation(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "set_rotation",
    {
      description:
        "Rotate the device screen to a specific orientation. Values: 0=portrait, 1=landscape left, 2=reverse portrait, 3=landscape right. " +
        "Use this to test how an app looks in different orientations. Take a screenshot after to verify the new layout. " +
        "Related: get_orientation (check current orientation), get_screen_size (dimensions change after rotation), get_screenshot (verify new layout).",
      inputSchema: {
        device_id: deviceIdSchema,
        rotation: z.number().describe("0=portrait, 1=landscape left, 2=reverse portrait, 3=landscape right"),
      },
    },
    async ({ device_id, rotation }) => {
      try {
        const result = await hub.post<ActionResult>(`/devices/${device_id}/rotation`, { rotation });
        const names: Record<number, string> = { 0: "portrait", 1: "landscape", 2: "reverse portrait", 3: "reverse landscape" };
        return createTextResponse(result, `Rotated to ${names[rotation] || "unknown"}`);
      } catch (error) {
        return createErrorResponse(error, "Could not rotate screen");
      }
    }
  );
}

export function registerToggleWifi(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "toggle_wifi",
    {
      description:
        "Turn WiFi on or off on the device. Use this to test offline behavior, network error handling, or connectivity-dependent features. " +
        "Set enabled=true to turn on, enabled=false to turn off. " +
        "Related: toggle_airplane_mode (disable all radios at once).",
      inputSchema: {
        device_id: deviceIdSchema,
        enabled: z.boolean().describe("true to enable WiFi, false to disable"),
      },
    },
    async ({ device_id, enabled }) => {
      try {
        const result = await hub.post<ActionResult>(`/devices/${device_id}/wifi`, { enabled });
        return createTextResponse(result, `WiFi ${enabled ? "enabled" : "disabled"}`);
      } catch (error) {
        return createErrorResponse(error, "Could not toggle WiFi");
      }
    }
  );
}

export function registerToggleAirplane(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "toggle_airplane_mode",
    {
      description:
        "Turn airplane mode on or off. Airplane mode disables all wireless radios (WiFi, cellular, Bluetooth). " +
        "Use this to test complete offline scenarios. Set enabled=true to enable, enabled=false to disable. " +
        "Related: toggle_wifi (control WiFi only).",
      inputSchema: {
        device_id: deviceIdSchema,
        enabled: z.boolean().describe("true to enable airplane mode, false to disable"),
      },
    },
    async ({ device_id, enabled }) => {
      try {
        const result = await hub.post<ActionResult>(`/devices/${device_id}/airplane`, { enabled });
        return createTextResponse(result, `Airplane mode ${enabled ? "enabled" : "disabled"}`);
      } catch (error) {
        return createErrorResponse(error, "Could not toggle airplane mode");
      }
    }
  );
}

export function registerGrantPermissions(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "grant_permissions",
    {
      description:
        "Auto-grant all runtime permissions (camera, location, storage, contacts, etc.) for an app. " +
        "Use this before testing to avoid permission popup dialogs that interrupt automation. " +
        "Call this after install_app or clear_app_data since permissions are reset. " +
        "Related: install_app (can also grant on install), clear_app_data (resets permissions), launch_app (open the app after granting).",
      inputSchema: {
        device_id: deviceIdSchema,
        package: packageSchema,
      },
    },
    async ({ device_id, package: pkg }) => {
      try {
        const result = await hub.post<ActionResult>(`/devices/${device_id}/grant-permissions`, { package: pkg });
        return createTextResponse(result, `Granted all permissions for ${pkg.split(".").pop()}`);
      } catch (error) {
        return createErrorResponse(error, "Could not grant permissions");
      }
    }
  );
}

export function registerGetNotifications(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "get_notifications",
    {
      description:
        "Read all current notifications from the device's notification bar. Returns each notification's title, text content, and source app package. " +
        "Use this to verify push notifications arrived, check for error notifications, or see what alerts are showing. " +
        "Returns: Array of notifications with title, text, and package name. " +
        "Related: get_screenshot (see notifications visually), get_device_logs (see notification-related logs).",
      inputSchema: {
        device_id: deviceIdSchema,
      },
    },
    async ({ device_id }) => {
      try {
        const result = await hub.get<ActionResult>(`/devices/${device_id}/notifications`);
        const data = result as unknown as { data?: { count?: number } };
        return createTextResponse(result, `Found ${data?.data?.count ?? 0} notification(s)`);
      } catch (error) {
        return createErrorResponse(error, "Could not read notifications");
      }
    }
  );
}

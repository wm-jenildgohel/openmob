import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { HubClient } from "../../common/hub-client.js";
import { deviceIdSchema, packageSchema } from "../../common/schemas.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import type { ActionResult } from "../../../types/index.js";

export function registerListApps(server: McpServer, hub: HubClient): void {
  server.registerTool(
    "list_apps",
    {
      description: "List all installed apps on the device. Shows package names. Use third_party_only to filter to user-installed apps (excludes system apps).",
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
  server.registerTool(
    "get_current_activity",
    {
      description: "See which app and screen is currently in the foreground on the device.",
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
  server.registerTool(
    "clear_app_data",
    {
      description: "Clear all data for an app — like a fresh install. Removes saved settings, login, cache, everything.",
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
  server.registerTool(
    "get_device_logs",
    {
      description: "Get recent device logs (logcat). Filter by app tag, log level, or number of lines. Useful for debugging crashes, errors, and app behavior.",
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
  server.registerTool(
    "wait_for_element",
    {
      description: "Wait until a specific UI element appears on screen. Useful after navigation, loading screens, or animations. Returns the element's index for tapping.",
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
  server.registerTool(
    "set_rotation",
    {
      description: "Rotate the device screen. 0=portrait, 1=landscape (left), 2=reverse portrait, 3=landscape (right).",
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
  server.registerTool(
    "toggle_wifi",
    {
      description: "Turn WiFi on or off on the device.",
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
  server.registerTool(
    "toggle_airplane_mode",
    {
      description: "Turn airplane mode on or off on the device.",
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
  server.registerTool(
    "grant_permissions",
    {
      description: "Auto-grant all runtime permissions for an app — camera, location, storage, etc. Useful to avoid permission popups during testing.",
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
  server.registerTool(
    "get_notifications",
    {
      description: "Read the device's notification bar — see all current notifications with their title, text, and source app.",
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

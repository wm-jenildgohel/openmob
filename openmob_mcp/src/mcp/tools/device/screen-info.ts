import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { HubClient } from "../../common/hub-client.js";
import { deviceIdSchema } from "../../common/schemas.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import { registerToolDual } from "../../common/dual-register.js";
import type { ActionResult } from "../../../types/index.js";

export function registerGetScreenSize(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "get_screen_size",
    {
      description:
        "Get the device screen dimensions in pixels. Returns width and height. " +
        "Use this when you need exact coordinates for swipe or tap by position. " +
        "Also useful for determining portrait vs landscape orientation. " +
        "Returns: {width, height} in pixels. " +
        "Related: get_orientation (check portrait/landscape), swipe (needs screen bounds for custom coordinates).",
      inputSchema: {
        device_id: deviceIdSchema,
      },
    },
    async ({ device_id }) => {
      try {
        const result = await hub.get<ActionResult>(`/devices/${device_id}/screen-size`);
        const data = result as unknown as { data?: { width?: number; height?: number } };
        const w = data?.data?.width ?? 0;
        const h = data?.data?.height ?? 0;
        return createTextResponse(result, `Screen size: ${w}x${h} pixels`);
      } catch (error) {
        return createErrorResponse(error, "Could not get screen size — check device connection");
      }
    }
  );
}

export function registerGetOrientation(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "get_orientation",
    {
      description:
        "Check if the device is in portrait or landscape mode. " +
        "Returns the current orientation name and rotation value (0=portrait, 1=landscape left, 2=reverse portrait, 3=landscape right). " +
        "Use this before calculating tap coordinates that depend on screen layout. " +
        "Related: set_rotation (change orientation), get_screen_size (get dimensions).",
      inputSchema: {
        device_id: deviceIdSchema,
      },
    },
    async ({ device_id }) => {
      try {
        const result = await hub.get<ActionResult>(`/devices/${device_id}/orientation`);
        const data = result as unknown as { data?: { orientation?: string } };
        const orient = data?.data?.orientation ?? "unknown";
        return createTextResponse(result, `Device is in ${orient} mode`);
      } catch (error) {
        return createErrorResponse(error, "Could not determine orientation");
      }
    }
  );
}

export function registerSaveScreenshot(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "save_screenshot",
    {
      description:
        "Save a screenshot as a PNG file on the host computer. Unlike get_screenshot which returns the image inline, this saves to disk at the path you specify. " +
        "Use this when you need to save evidence, create before/after comparisons, or archive screenshots for reports. " +
        "Returns: {path, width, height} confirming where the file was saved. " +
        "Related: get_screenshot (view screen inline instead of saving), start_recording (capture video instead).",
      inputSchema: {
        device_id: deviceIdSchema,
        path: z.string().describe("Full file path where the screenshot PNG should be saved (e.g., '/tmp/screenshot.png')"),
      },
    },
    async ({ device_id, path }) => {
      try {
        const result = await hub.post<ActionResult>(`/devices/${device_id}/save-screenshot`, { path });
        const data = result as unknown as { data?: { width?: number; height?: number; path?: string } };
        const w = data?.data?.width ?? 0;
        const h = data?.data?.height ?? 0;
        return createTextResponse(result, `Screenshot saved to ${path} (${w}x${h})`);
      } catch (error) {
        return createErrorResponse(error, "Could not save screenshot — check the file path and device connection");
      }
    }
  );
}

export function registerFindElement(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "find_element",
    {
      description:
        "Search for UI elements by text, class name, or resource ID. More powerful than get_ui_tree's text_filter because it searches across text content, content descriptions, class names, and resource IDs simultaneously. " +
        "Use this when get_ui_tree returns too many elements and you need a targeted search. " +
        "Returns: Matching elements with their index numbers so you can pass them to tap. " +
        "Example: find_element(text='Login') finds all buttons/labels containing 'Login'. " +
        "Related: get_ui_tree (get all elements), tap (interact with found elements), wait_for_element (wait for element to appear).",
      inputSchema: {
        device_id: deviceIdSchema,
        text: z.string().optional().describe("Search by visible text or content description (case-insensitive, partial match)"),
        class_name: z.string().optional().describe("Search by UI class name (e.g., 'Button', 'EditText', 'TextView')"),
        resource_id: z.string().optional().describe("Search by resource ID (e.g., 'com.app:id/login_btn')"),
      },
    },
    async ({ device_id, text, class_name, resource_id }) => {
      try {
        const params = new URLSearchParams();
        if (text) params.set("text", text);
        if (class_name) params.set("class", class_name);
        if (resource_id) params.set("resource_id", resource_id);
        const qs = params.toString() ? `?${params.toString()}` : "";

        const result = await hub.get<ActionResult>(`/devices/${device_id}/find-element${qs}`);
        const data = result as unknown as { data?: { found?: boolean; count?: number } };
        const count = data?.data?.count ?? 0;
        const searchTerms = [text, class_name, resource_id].filter(Boolean).join(", ");

        if (count === 0) {
          return createTextResponse(result, `No elements found matching "${searchTerms}" — try a different search or take a screenshot`);
        }
        return createTextResponse(result, `Found ${count} element${count > 1 ? "s" : ""} matching "${searchTerms}"`);
      } catch (error) {
        return createErrorResponse(error, "Could not search for elements — the screen may be loading");
      }
    }
  );
}

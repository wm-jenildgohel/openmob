import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { HubClient } from "../../common/hub-client.js";
import { deviceIdSchema } from "../../common/schemas.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import { registerToolDual } from "../../common/dual-register.js";
import type { ActionResult } from "../../../types/index.js";

export function registerLongPress(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "long_press",
    {
      description:
        "Long-press (press and hold) on the device screen. Opens context menus, triggers drag mode, selects items, or activates edit mode on home screens. " +
        "Default hold duration is 1500ms (1.5 seconds). Customize with the duration parameter. " +
        "Accepts element index (from get_ui_tree) or x,y coordinates. " +
        "Returns: Confirmation of the long-press action and duration. " +
        "Related: tap (single tap), double_tap (double tap), get_ui_tree (get element indices), get_screenshot (see context menu that appeared).",
      inputSchema: {
        device_id: deviceIdSchema,
        x: z.number().optional().describe("X coordinate on screen"),
        y: z.number().optional().describe("Y coordinate on screen"),
        index: z.number().optional().describe("Element number from get_ui_tree — recommended over coordinates"),
        duration: z.number().optional().describe("How long to hold in milliseconds (default: 1500)"),
      },
    },
    async ({ device_id, x, y, index, duration }) => {
      try {
        const body: Record<string, unknown> =
          index !== undefined
            ? { index, duration: duration ?? 1500 }
            : { x, y, duration: duration ?? 1500 };
        const result = await hub.post<ActionResult>(`/devices/${device_id}/long-press`, body);

        const durationSec = ((duration ?? 1500) / 1000).toFixed(1);
        const summary = index !== undefined
          ? `Long-pressed element #${index} for ${durationSec}s`
          : `Long-pressed at (${x}, ${y}) for ${durationSec}s`;

        return createTextResponse(result, summary);
      } catch (error) {
        return createErrorResponse(error, "Could not long-press — check device connection");
      }
    }
  );
}

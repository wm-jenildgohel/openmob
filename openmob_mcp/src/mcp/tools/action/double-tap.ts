import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { HubClient } from "../../common/hub-client.js";
import { deviceIdSchema } from "../../common/schemas.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import { registerToolDual } from "../../common/dual-register.js";
import type { ActionResult } from "../../../types/index.js";

export function registerDoubleTap(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "double_tap",
    {
      description:
        "Double-tap on the device screen — two quick taps in succession. " +
        "Use this for zooming into maps, images, or web pages; selecting a word of text; or triggering double-tap gestures in apps. " +
        "Accepts element index (from get_ui_tree) or x,y coordinates. " +
        "Returns: Confirmation of which element or position was double-tapped. " +
        "Related: tap (single tap), long_press (press and hold), get_ui_tree (get element indices).",
      inputSchema: {
        device_id: deviceIdSchema,
        x: z.number().optional().describe("X coordinate on screen"),
        y: z.number().optional().describe("Y coordinate on screen"),
        index: z.number().optional().describe("Element number from get_ui_tree — recommended over coordinates"),
      },
    },
    async ({ device_id, x, y, index }) => {
      try {
        const body: Record<string, unknown> =
          index !== undefined ? { index } : { x, y };
        const result = await hub.post<ActionResult>(`/devices/${device_id}/double-tap`, body);

        const summary = index !== undefined
          ? `Double-tapped element #${index}`
          : `Double-tapped at position (${x}, ${y})`;

        return createTextResponse(result, summary);
      } catch (error) {
        return createErrorResponse(error, "Could not double-tap — check if the device is still connected");
      }
    }
  );
}

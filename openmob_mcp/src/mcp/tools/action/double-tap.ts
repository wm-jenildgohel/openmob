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
        "Double-tap on the device screen — like quickly tapping twice with your finger. Useful for zooming into maps/images or selecting text. Use element index (from get_ui_tree) or x,y coordinates.",
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

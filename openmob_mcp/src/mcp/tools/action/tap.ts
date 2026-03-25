import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { HubClient } from "../../common/hub-client.js";
import { deviceIdSchema } from "../../common/schemas.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import type { ActionResult } from "../../../types/index.js";

export function registerTap(server: McpServer, hub: HubClient): void {
  server.registerTool(
    "tap",
    {
      description:
        "Tap on the device screen — like a finger touch. Use element index (from get_ui_tree) to tap a specific button/field, or x,y coordinates for precise position.",
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
        const result = await hub.post<ActionResult>(`/devices/${device_id}/tap`, body);

        const summary = index !== undefined
          ? `Tapped element #${index} on the screen`
          : `Tapped at position (${x}, ${y}) on the screen`;

        return createTextResponse(result, summary);
      } catch (error) {
        return createErrorResponse(error, "Could not tap on the device — check if the device is still connected");
      }
    }
  );
}

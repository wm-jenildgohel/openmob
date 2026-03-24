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
        "Tap on the device screen. Provide either x,y coordinates or a UI element index from get_ui_tree.",
      inputSchema: {
        device_id: deviceIdSchema,
        x: z.number().optional().describe("X coordinate"),
        y: z.number().optional().describe("Y coordinate"),
        index: z.number().optional().describe("UI element index from get_ui_tree"),
      },
    },
    async ({ device_id, x, y, index }) => {
      try {
        const body: Record<string, unknown> =
          index !== undefined ? { index } : { x, y };
        const result = await hub.post<ActionResult>(`/devices/${device_id}/tap`, body);
        return createTextResponse(result);
      } catch (error) {
        return createErrorResponse(error);
      }
    }
  );
}

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { HubClient } from "../../common/hub-client.js";
import { deviceIdSchema } from "../../common/schemas.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import type { ActionResult } from "../../../types/index.js";

export function registerSwipe(server: McpServer, hub: HubClient): void {
  server.registerTool(
    "swipe",
    {
      description:
        "Perform a swipe gesture on the device screen from start point to end point.",
      inputSchema: {
        device_id: deviceIdSchema,
        x1: z.number().describe("Start X"),
        y1: z.number().describe("Start Y"),
        x2: z.number().describe("End X"),
        y2: z.number().describe("End Y"),
        duration: z.number().optional().describe("Duration in milliseconds (default 300)"),
      },
    },
    async ({ device_id, x1, y1, x2, y2, duration }) => {
      try {
        const result = await hub.post<ActionResult>(`/devices/${device_id}/swipe`, {
          x1,
          y1,
          x2,
          y2,
          duration,
        });
        return createTextResponse(result);
      } catch (error) {
        return createErrorResponse(error);
      }
    }
  );
}

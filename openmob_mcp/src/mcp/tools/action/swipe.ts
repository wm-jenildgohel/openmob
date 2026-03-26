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
        "Swipe on the device screen — like scrolling or swiping between pages. Use 'up' to scroll down (revealing content below), 'down' to scroll up, 'left'/'right' for horizontal swipes. You can also specify exact start and end coordinates.",
      inputSchema: {
        device_id: deviceIdSchema,
        direction: z.enum(["up", "down", "left", "right"]).optional().describe("Swipe direction — 'up' scrolls content down, 'down' scrolls content up"),
        x1: z.number().optional().describe("Start X (use instead of direction for precise control)"),
        y1: z.number().optional().describe("Start Y"),
        x2: z.number().optional().describe("End X"),
        y2: z.number().optional().describe("End Y"),
        duration: z.number().optional().describe("How long the swipe takes in milliseconds (default 300, slower = more precise)"),
      },
    },
    async ({ device_id, direction, x1, y1, x2, y2, duration }) => {
      try {
        let body: Record<string, unknown>;
        let summary: string;

        if (direction) {
          // Convert direction to coordinates (center of screen, 1/3 distance)
          body = { direction, duration };
          const dirMap: Record<string, string> = {
            up: "Scrolled down to see more content",
            down: "Scrolled up toward the top",
            left: "Swiped left to next page/item",
            right: "Swiped right to previous page/item",
          };
          summary = dirMap[direction] || `Swiped ${direction}`;
        } else {
          body = { x1, y1, x2, y2, duration };
          summary = `Swiped from (${x1},${y1}) to (${x2},${y2})`;
        }

        const result = await hub.post<ActionResult>(`/devices/${device_id}/swipe`, body);
        return createTextResponse(result, summary);
      } catch (error) {
        return createErrorResponse(error, "Could not swipe — the device might be unresponsive");
      }
    }
  );
}

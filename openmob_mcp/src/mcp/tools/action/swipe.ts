import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { HubClient } from "../../common/hub-client.js";
import { deviceIdSchema } from "../../common/schemas.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import { registerToolDual } from "../../common/dual-register.js";
import type { ActionResult } from "../../../types/index.js";

export function registerSwipe(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "swipe",
    {
      description:
        "Swipe/scroll on the device screen. Use direction for simple scrolling: 'up' scrolls content DOWN (reveals content below), 'down' scrolls content UP, 'left'/'right' for horizontal navigation. " +
        "For precise control, specify exact start (x1,y1) and end (x2,y2) coordinates. " +
        "Adjust duration for slower/more precise swipes (default 300ms). " +
        "Use this to scroll through lists, swipe between pages, pull-to-refresh, or dismiss notifications. " +
        "Returns: Confirmation of swipe direction and distance. " +
        "Related: get_screenshot (verify scroll result), get_ui_tree (find elements after scrolling), get_screen_size (know bounds for coordinates).",
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

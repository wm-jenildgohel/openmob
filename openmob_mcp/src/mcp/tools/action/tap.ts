import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { HubClient } from "../../common/hub-client.js";
import { deviceIdSchema } from "../../common/schemas.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import { registerToolDual } from "../../common/dual-register.js";
import type { ActionResult } from "../../../types/index.js";

export function registerTap(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "tap",
    {
      description:
        "Tap on the device screen — the primary way to interact with UI elements. " +
        "PREFERRED: Pass an element index (from get_ui_tree) to tap a specific button, field, or link reliably. " +
        "ALTERNATIVE: Pass x,y pixel coordinates for precise position tapping when indices are unavailable. " +
        "Always call get_screenshot after tapping to verify the result. " +
        "Returns: Confirmation of which element or position was tapped. " +
        "Related: get_ui_tree (get element indices first), double_tap (tap twice), long_press (press and hold), get_screenshot (verify after tap).",
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

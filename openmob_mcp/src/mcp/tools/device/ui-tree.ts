import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { HubClient } from "../../common/hub-client.js";
import { deviceIdSchema } from "../../common/schemas.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import { registerToolDual } from "../../common/dual-register.js";
import type { UiTreeResult } from "../../../types/index.js";

export function registerGetUiTree(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "get_ui_tree",
    {
      description:
        "Get all UI elements currently on the device screen — buttons, text fields, labels, images, etc. — each with an index number, position, and text content. " +
        "Use the index numbers with tap, double_tap, or long_press to interact with specific elements. " +
        "Use text_filter to search for a specific element (e.g., 'Login'). Set visible_only=true to ignore hidden elements. " +
        "Returns: Array of UI nodes with index, text, class, bounds, and resource-id. " +
        "Related: tap (interact with elements), find_element (advanced search by class/resource-id), get_screenshot (visual view).",
      inputSchema: {
        device_id: deviceIdSchema,
        text_filter: z.string().optional().describe("Search for elements containing this text (e.g., 'Login', 'Submit', 'Email')"),
        visible_only: z.boolean().optional().describe("Only show elements that are visible on screen (recommended: true)"),
      },
    },
    async ({ device_id, text_filter, visible_only }) => {
      try {
        const params = new URLSearchParams();
        if (text_filter !== undefined) params.set("text", text_filter);
        if (visible_only !== undefined) params.set("visible", String(visible_only));
        const queryString = params.toString() ? `?${params.toString()}` : "";

        const data = await hub.get<UiTreeResult>(`/devices/${device_id}/ui-tree${queryString}`);
        const count = data.nodes.length;

        let summary: string;
        if (count === 0) {
          summary = text_filter
            ? `No elements found matching "${text_filter}" — try a different search or take a screenshot to see what's on screen`
            : "No UI elements found — the screen might be loading or showing a system dialog";
        } else {
          summary = text_filter
            ? `Found ${count} element${count > 1 ? "s" : ""} matching "${text_filter}"`
            : `Found ${count} UI element${count > 1 ? "s" : ""} on screen`;
        }

        return createTextResponse(data.nodes, summary);
      } catch (error) {
        return createErrorResponse(error, "Could not read the screen — the app might be loading or in a transition");
      }
    }
  );
}

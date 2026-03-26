import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { HubClient } from "../../common/hub-client.js";
import { deviceIdSchema } from "../../common/schemas.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import type { UiTreeResult } from "../../../types/index.js";

export function registerGetUiTree(server: McpServer, hub: HubClient): void {
  server.registerTool(
    "get_ui_tree",
    {
      description:
        "Read what's on the device screen — returns a list of all buttons, text fields, labels, and other UI elements with their positions and index numbers. Use the index numbers with the 'tap' tool to interact with specific elements. Optionally filter by text to find specific elements quickly.",
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

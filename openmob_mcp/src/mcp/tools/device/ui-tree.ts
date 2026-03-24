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
        "Get the UI accessibility tree from a device. Returns elements with index numbers that can be used with the tap tool. Optionally filter by text pattern or visibility.",
      inputSchema: {
        device_id: deviceIdSchema,
        text_filter: z.string().optional().describe("Regex pattern to filter elements by text"),
        visible_only: z.boolean().optional().describe("Only return visible elements"),
      },
    },
    async ({ device_id, text_filter, visible_only }) => {
      try {
        const params = new URLSearchParams();
        if (text_filter !== undefined) params.set("text", text_filter);
        if (visible_only !== undefined) params.set("visible", String(visible_only));
        const queryString = params.toString() ? `?${params.toString()}` : "";

        const data = await hub.get<UiTreeResult>(`/devices/${device_id}/ui-tree${queryString}`);
        return createTextResponse(data.nodes);
      } catch (error) {
        return createErrorResponse(error);
      }
    }
  );
}

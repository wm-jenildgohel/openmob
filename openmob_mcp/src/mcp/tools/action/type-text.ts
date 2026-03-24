import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { HubClient } from "../../common/hub-client.js";
import { deviceIdSchema } from "../../common/schemas.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import type { ActionResult } from "../../../types/index.js";

export function registerTypeText(server: McpServer, hub: HubClient): void {
  server.registerTool(
    "type_text",
    {
      description: "Type text into the currently focused input field on the device.",
      inputSchema: {
        device_id: deviceIdSchema,
        text: z.string().describe("Text to type"),
      },
    },
    async ({ device_id, text }) => {
      try {
        const result = await hub.post<ActionResult>(`/devices/${device_id}/type`, { text });
        return createTextResponse(result);
      } catch (error) {
        return createErrorResponse(error);
      }
    }
  );
}

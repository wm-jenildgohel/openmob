import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { HubClient } from "../../common/hub-client.js";
import { deviceIdSchema } from "../../common/schemas.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import type { ActionResult } from "../../../types/index.js";

export function registerGoHome(server: McpServer, hub: HubClient): void {
  server.registerTool(
    "go_home",
    {
      description: "Navigate to the home screen on the device.",
      inputSchema: {
        device_id: deviceIdSchema,
      },
    },
    async ({ device_id }) => {
      try {
        const result = await hub.post<ActionResult>(`/devices/${device_id}/keyevent`, {
          keyCode: 3,
        });
        return createTextResponse(result);
      } catch (error) {
        return createErrorResponse(error);
      }
    }
  );
}

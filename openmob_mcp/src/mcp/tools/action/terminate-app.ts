import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { HubClient } from "../../common/hub-client.js";
import { deviceIdSchema, packageSchema } from "../../common/schemas.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import type { ActionResult } from "../../../types/index.js";

export function registerTerminateApp(server: McpServer, hub: HubClient): void {
  server.registerTool(
    "terminate_app",
    {
      description: "Force-stop a running app on the device.",
      inputSchema: {
        device_id: deviceIdSchema,
        package: packageSchema,
      },
    },
    async ({ device_id, package: pkg }) => {
      try {
        const result = await hub.post<ActionResult>(`/devices/${device_id}/terminate`, {
          package: pkg,
        });
        return createTextResponse(result);
      } catch (error) {
        return createErrorResponse(error);
      }
    }
  );
}

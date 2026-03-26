import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { HubClient } from "../../common/hub-client.js";
import { deviceIdSchema, packageSchema } from "../../common/schemas.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import { registerToolDual } from "../../common/dual-register.js";
import type { ActionResult } from "../../../types/index.js";

export function registerTerminateApp(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "terminate_app",
    {
      description: "Close/kill a running app on the device. The app will be force-stopped.",
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
        const appName = pkg.split(".").pop() || pkg;
        return createTextResponse(result, `Closed the ${appName} app`);
      } catch (error) {
        return createErrorResponse(error, "Could not close the app — it may not be running");
      }
    }
  );
}

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
      description:
        "Force-close a running app on the device. The app process is killed immediately — unsaved data may be lost. " +
        "Use this to stop a misbehaving app, clear its runtime state, or free device resources. " +
        "Returns: Confirmation that the app was terminated. " +
        "Related: launch_app (restart the app), clear_app_data (also wipe stored data), get_current_activity (check what's running).",
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

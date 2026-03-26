import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { HubClient } from "../../common/hub-client.js";
import { deviceIdSchema, packageSchema } from "../../common/schemas.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import type { ActionResult } from "../../../types/index.js";

export function registerLaunchApp(server: McpServer, hub: HubClient): void {
  server.registerTool(
    "launch_app",
    {
      description:
        "Open an app on the device. Provide the app's package name (Android, e.g., 'com.example.myapp') or bundle ID (iOS, e.g., 'com.example.MyApp').",
      inputSchema: {
        device_id: deviceIdSchema,
        package: packageSchema,
      },
    },
    async ({ device_id, package: pkg }) => {
      try {
        const result = await hub.post<ActionResult>(`/devices/${device_id}/launch`, {
          package: pkg,
        });
        const appName = pkg.split(".").pop() || pkg;
        return createTextResponse(result, `Opened the ${appName} app`);
      } catch (error) {
        return createErrorResponse(error, "Could not open the app — it may not be installed on this device");
      }
    }
  );
}

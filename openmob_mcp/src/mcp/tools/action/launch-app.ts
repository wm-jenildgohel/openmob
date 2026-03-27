import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { HubClient } from "../../common/hub-client.js";
import { deviceIdSchema, packageSchema } from "../../common/schemas.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import { registerToolDual } from "../../common/dual-register.js";
import type { ActionResult } from "../../../types/index.js";

export function registerLaunchApp(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "launch_app",
    {
      description:
        "Open/launch an app on the device by its package name (Android, e.g., 'com.android.settings') or bundle ID (iOS, e.g., 'com.apple.mobilesafari'). " +
        "If the app is already running, it brings it to the foreground. If not running, it cold-starts it. " +
        "Use list_apps to find the correct package name if you don't know it. " +
        "Returns: Confirmation that the app was launched. " +
        "Related: list_apps (find package names), terminate_app (close an app), get_current_activity (verify which app is in foreground), get_screenshot (see the launched app).",
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

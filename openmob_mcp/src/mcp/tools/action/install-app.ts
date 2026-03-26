import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { HubClient } from "../../common/hub-client.js";
import { deviceIdSchema } from "../../common/schemas.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import { registerToolDual } from "../../common/dual-register.js";
import type { ActionResult } from "../../../types/index.js";

export function registerInstallApp(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "install_app",
    {
      description: "Install an APK on the device from a file path on this computer.",
      inputSchema: {
        device_id: deviceIdSchema,
        path: z.string().describe("Full path to the APK file on this computer"),
        replace: z.boolean().optional().describe("Replace existing app if installed (default: true)"),
        grant_permissions: z.boolean().optional().describe("Auto-grant all permissions (default: true)"),
      },
    },
    async ({ device_id, path, replace, grant_permissions }) => {
      try {
        const result = await hub.post<ActionResult>(`/devices/${device_id}/install`, {
          path, replace: replace ?? true, grant_permissions: grant_permissions ?? true,
        });
        return createTextResponse(result, `Installed app from ${path.split(/[/\\]/).pop()}`);
      } catch (error) {
        return createErrorResponse(error, "Could not install the app — check the APK path");
      }
    }
  );
}

export function registerUninstallApp(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "uninstall_app",
    {
      description: "Uninstall an app from the device by package name.",
      inputSchema: {
        device_id: deviceIdSchema,
        package: z.string().describe("App package name (e.g., com.example.myapp)"),
      },
    },
    async ({ device_id, package: pkg }) => {
      try {
        const result = await hub.post<ActionResult>(`/devices/${device_id}/uninstall`, { package: pkg });
        return createTextResponse(result, `Uninstalled ${pkg.split(".").pop()}`);
      } catch (error) {
        return createErrorResponse(error, "Could not uninstall — the app may not be installed");
      }
    }
  );
}

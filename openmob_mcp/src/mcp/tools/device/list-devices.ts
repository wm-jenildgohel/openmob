import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { HubClient } from "../../common/hub-client.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import type { Device } from "../../../types/index.js";

export function registerListDevices(server: McpServer, hub: HubClient): void {
  server.registerTool(
    "list_devices",
    {
      description:
        "List all connected mobile devices (Android and iOS) with metadata including model, OS version, screen size, and connection status",
    },
    async () => {
      try {
        const devices = await hub.get<Device[]>("/devices");
        return createTextResponse(devices);
      } catch (error) {
        return createErrorResponse(error);
      }
    }
  );
}

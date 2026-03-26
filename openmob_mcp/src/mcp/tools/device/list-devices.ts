import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { HubClient } from "../../common/hub-client.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import type { Device } from "../../../types/index.js";

export function registerListDevices(server: McpServer, hub: HubClient): void {
  server.registerTool(
    "list_devices",
    {
      description:
        "See all connected mobile devices — shows each device's name, model, OS version, screen size, battery level, and how it's connected (USB/WiFi/emulator). Use the device ID from this list in all other tools.",
    },
    async () => {
      try {
        const devices = await hub.get<Device[]>("/devices");
        const count = devices.length;
        const summary = count === 0
          ? "No devices connected — connect a device via USB or start an emulator"
          : `Found ${count} device${count > 1 ? "s" : ""}: ${devices.map(d => `${d.model} (${d.platform}, ${d.connectionType})`).join(", ")}`;
        return createTextResponse(devices, summary);
      } catch (error) {
        return createErrorResponse(error, "Could not list devices — is OpenMob Hub running?");
      }
    }
  );
}

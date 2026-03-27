import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { HubClient } from "../../common/hub-client.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import { registerToolDual } from "../../common/dual-register.js";
import type { Device } from "../../../types/index.js";

export function registerListDevices(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "list_devices",
    {
      description:
        "See all connected mobile devices. Returns each device's ID, name, model, OS version, screen size, battery level, and connection type (USB/WiFi/emulator). " +
        "ALWAYS call this first before using any other tool — you need the device_id from this list. " +
        "If no devices appear, connect one via USB or start an emulator. " +
        "Related: get_screenshot (see what's on screen), get_ui_tree (read UI elements).",
    },
    async () => {
      try {
        const devices = await hub.get<Device[]>("/devices/");
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

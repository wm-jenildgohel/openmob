import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { HubClient } from "../../common/hub-client.js";
import { registerListDevices } from "./list-devices.js";
import { registerGetScreenshot } from "./screenshot.js";
import { registerGetUiTree } from "./ui-tree.js";
import {
  registerListApps,
  registerGetCurrentActivity,
  registerClearAppData,
  registerGetLogs,
  registerWaitForElement,
  registerSetRotation,
  registerToggleWifi,
  registerToggleAirplane,
  registerGrantPermissions,
  registerGetNotifications,
} from "./device-info.js";

export function registerDeviceTools(server: McpServer, hub: HubClient): void {
  registerListDevices(server, hub);
  registerGetScreenshot(server, hub);
  registerGetUiTree(server, hub);
  registerListApps(server, hub);
  registerGetCurrentActivity(server, hub);
  registerClearAppData(server, hub);
  registerGetLogs(server, hub);
  registerWaitForElement(server, hub);
  registerSetRotation(server, hub);
  registerToggleWifi(server, hub);
  registerToggleAirplane(server, hub);
  registerGrantPermissions(server, hub);
  registerGetNotifications(server, hub);
}

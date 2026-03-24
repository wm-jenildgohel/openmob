import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { HubClient } from "../../common/hub-client.js";
import { registerListDevices } from "./list-devices.js";
import { registerGetScreenshot } from "./screenshot.js";
import { registerGetUiTree } from "./ui-tree.js";

export function registerDeviceTools(server: McpServer, hub: HubClient): void {
  registerListDevices(server, hub);
  registerGetScreenshot(server, hub);
  registerGetUiTree(server, hub);
}

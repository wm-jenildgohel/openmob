import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { HubClient } from "../../common/hub-client.js";
import { registerTap } from "./tap.js";
import { registerTypeText } from "./type-text.js";
import { registerSwipe } from "./swipe.js";
import { registerPressButton } from "./press-button.js";
import { registerGoHome } from "./go-home.js";
import { registerLaunchApp } from "./launch-app.js";
import { registerTerminateApp } from "./terminate-app.js";
import { registerOpenUrl } from "./open-url.js";

export function registerActionTools(server: McpServer, hub: HubClient): void {
  registerTap(server, hub);
  registerTypeText(server, hub);
  registerSwipe(server, hub);
  registerPressButton(server, hub);
  registerGoHome(server, hub);
  registerLaunchApp(server, hub);
  registerTerminateApp(server, hub);
  registerOpenUrl(server, hub);
}

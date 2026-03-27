import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { HubClient } from "../../common/hub-client.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import { registerToolDual } from "../../common/dual-register.js";

export function registerPairWireless(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "pair_wireless",
    {
      description:
        "Pair with an Android device wirelessly (Android 11+). On the device: Settings → Developer Options → Wireless Debugging → Pair with pairing code. Enter the IP:port and 6-digit code shown on the device.",
      inputSchema: {
        address: z.string().describe("IP:port shown on the device (e.g., '192.168.1.5:37123')"),
        pairing_code: z.string().describe("6-digit pairing code shown on the device"),
      },
    },
    async ({ address, pairing_code }) => {
      try {
        const result = await hub.post<{ success: boolean; error?: string }>(
          "/devices/pair-wireless",
          { address, pairing_code }
        );
        if (result.success) {
          return createTextResponse(result, "Device paired successfully! Now use connect_wireless to connect.");
        }
        return createTextResponse(result, result.error || "Pairing failed — check the code and try again");
      } catch (error) {
        return createErrorResponse(error, "Could not pair with device — check IP, port, and pairing code");
      }
    }
  );
}

export function registerConnectWireless(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "connect_wireless",
    {
      description:
        "Connect to an Android device over WiFi. The device must be on the same network. For Android 11+, pair first using pair_wireless. For older Android, the device must have been connected via USB first with 'adb tcpip 5555' enabled.",
      inputSchema: {
        address: z.string().describe("IP:port of the device (e.g., '192.168.1.5:5555')"),
      },
    },
    async ({ address }) => {
      try {
        const result = await hub.post<{ success: boolean; error?: string }>(
          "/devices/connect-wifi",
          { address }
        );
        if (result.success) {
          return createTextResponse(result, `Connected to ${address} wirelessly`);
        }
        return createTextResponse(result, result.error || "Connection failed — check the IP and port");
      } catch (error) {
        return createErrorResponse(error, "Could not connect wirelessly — is the device on the same network?");
      }
    }
  );
}

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { ToolCallback } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { ZodRawShapeCompat } from "@modelcontextprotocol/sdk/server/zod-compat.js";
import type { ToolAnnotations } from "@modelcontextprotocol/sdk/types.js";

/**
 * Register a tool under both its base name and a `mobile_` prefixed alias.
 * This provides backward compatibility with existing tool names while also
 * matching the mobile-mcp convention (e.g., `tap` + `mobile_tap`).
 */
export function registerToolDual<Args extends ZodRawShapeCompat>(
  server: McpServer,
  baseName: string,
  config: {
    title?: string;
    description?: string;
    inputSchema?: Args;
    annotations?: ToolAnnotations;
    _meta?: Record<string, unknown>;
  },
  cb: ToolCallback<Args>,
): void {
  server.registerTool(baseName, config, cb);
  server.registerTool(`mobile_${baseName}`, config, cb);
}

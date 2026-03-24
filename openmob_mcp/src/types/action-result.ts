export interface ActionResult {
  success: boolean;
  error?: string;
  data?: Record<string, unknown>;
}

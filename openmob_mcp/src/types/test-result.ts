export interface TestStep {
  action: string;
  params: Record<string, unknown>;
  assertion?: { type: string; [key: string]: unknown };
  description?: string;
}

export interface StepResult {
  stepIndex: number;
  action: string;
  success: boolean;
  error?: string;
  durationMs: number;
  screenshotBase64?: string;
  assertionResult?: Record<string, unknown>;
}

export interface TestResult {
  scriptId: string;
  scriptName: string;
  status: "passed" | "failed" | "running" | "error";
  steps: StepResult[];
  totalDurationMs: number;
  passedCount: number;
  failedCount: number;
  startedAt: string;
  completedAt?: string;
}

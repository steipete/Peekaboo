import { Logger } from "pino";
import { z } from "zod";

export interface SwiftCliResponse {
  success: boolean;
  data?: ApplicationListData | WindowListData | ImageCaptureData | ServerStatusData | unknown;
  messages?: string[];
  debug_logs?: string[];
  error?: {
    message: string;
    code: string;
    details?: string;
  };
}

export interface SavedFile {
  path: string;
  item_label?: string;
  window_title?: string;
  window_id?: number;
  window_index?: number;
  mime_type: string;
}

export interface ApplicationInfo {
  app_name: string;
  bundle_id: string;
  pid: number;
  is_active: boolean;
  window_count: number;
}

export interface WindowInfo {
  window_title: string;
  window_id?: number;
  window_index?: number;
  bounds?: {
    x: number;
    y: number;
    width: number;
    height: number;
  };
  is_on_screen?: boolean;
}

export interface TargetApplicationInfo {
  app_name: string;
  bundle_id?: string;
  pid: number;
}

export interface ToolContext {
  logger: Logger;
}

export interface ImageCaptureData {
  saved_files: SavedFile[];
}

export interface ApplicationListData {
  applications: ApplicationInfo[];
}

export interface WindowListData {
  target_application_info: TargetApplicationInfo;
  windows: WindowInfo[];
}

export interface ServerStatusData {
  cli_version?: string;
  permissions?: {
    screen_recording?: boolean;
    accessibility?: boolean;
  };
}

export interface AIProvider {
  provider: string;
  model: string;
}

export interface OllamaConfig {
  type: "ollama";
  baseUrl: string;
  model: string;
  requestTimeout?: number;
  keepAlive?: string;
}

export interface OpenAIConfig {
  type: "openai";
  apiKey?: string; // Optional because it can be set via env
  model: string;
  maxTokens?: number;
  temperature?: number;
}

export type AIProviderConfig = OllamaConfig | OpenAIConfig;

export interface ToolResponse {
  content: Array<{
    type: "text" | "image";
    text?: string;
    data?: string;
    mimeType?: string;
    metadata?: Record<string, unknown>;
  }>;
  isError?: boolean;
  saved_files?: SavedFile[];
  analysis_text?: string;
  model_used?: string;
  _meta?: Record<string, unknown>;
  [key: string]: unknown; // Allow additional properties
}

export const imageToolSchema = z.object({
  app_target: z.string().optional().describe(
    "Optional. Specifies the capture target.\n" +
    "For example:\n" +
    "Omit or use an empty string (e.g., `''`) for all screens.\n" +
    "Use `'screen:INDEX'` (e.g., `'screen:0'`) for a specific display.\n" +
    "Use `'frontmost'` for all windows of the current foreground application.\n" +
    "Use `'AppName'` (e.g., `'Safari'`) for all windows of that application.\n" +
    "Use `'AppName:WINDOW_TITLE:Title'` (e.g., `'TextEdit:WINDOW_TITLE:My Notes'`) for a window of 'AppName' matching that title.\n" +
    "Use `'AppName:WINDOW_INDEX:Index'` (e.g., `'Preview:WINDOW_INDEX:0'`) for a window of 'AppName' at that index.\n" +
    "Ensure components are correctly colon-separated.",
  ),
  path: z.string().optional().describe(
    "Optional. Base absolute path for saving the image.\n" +
    "Relevant if `format` is `'png'`, `'jpg'`, or if `'data'` is used with the intention to also save the file.\n" +
    "If a `question` is provided and `path` is omitted, a temporary path is used for image capture, and this temporary file is deleted after analysis.",
  ),
  question: z.string().optional().describe(
    "Optional. If provided, the captured image will be analyzed by an AI model.\n" +
    "The server automatically selects an AI provider from the `PEEKABOO_AI_PROVIDERS` environment variable.\n" +
    "The analysis result (text) is included in the response.",
  ),
  format: z.preprocess(
    (val) => {
      // Handle null, undefined, or empty string by returning undefined (will use default)
      if (val === null || val === undefined || val === "") {
        return undefined;
      }
      // If the value is not a valid format, fall back to 'png'
      const validFormats = ["png", "jpg", "data"];
      return validFormats.includes(val as string) ? val : "png";
    },
    z.enum(["png", "jpg", "data"]).optional().describe(
      "Optional. Output format.\n" +
      "Can be `'png'`, `'jpg'`, or `'data'`.\n" +
      "If `'png'` or `'jpg'`, saves the image to the specified `path`.\n" +
      "If `'data'`, returns Base64 encoded PNG data inline in the response.\n" +
      "If `path` is also provided when `format` is `'data'`, the image is saved (as PNG) AND Base64 data is returned.\n" +
      "Defaults to `'data'` if `path` is not given.\n" +
      "Invalid format values automatically fall back to 'png'.",
    ),
  ),
  capture_focus: z.preprocess(
    (val) => (val === "" || val === null ? undefined : val),
    z.enum(["background", "auto", "foreground"])
      .optional()
      .default("auto")
      .describe(
        "Optional. Focus behavior. 'auto' (default): bring target to front only if not already active. " +
        "'background': capture without altering window focus. " +
        "'foreground': always bring target to front before capture.",
      ),
  ),
})
  .describe(
    "Captures screen content and optionally analyzes it. " +
  "Targets entire screens, specific app windows, or all windows of an app (via `app_target`). " +
  "Supports foreground/background capture. " +
  "Output to file path or inline Base64 data (`format: \"data\"`). " +
  "If a `question` is provided, an AI model analyzes the image. " +
  "Window shadows/frames excluded.",
  );

export type ImageInput = z.infer<typeof imageToolSchema>;

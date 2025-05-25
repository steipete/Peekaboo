import { Logger } from "pino";
import { z } from "zod";

export interface SwiftCliResponse {
  success: boolean;
  data?: any;
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
    metadata?: any;
  }>;
  isError?: boolean;
  saved_files?: SavedFile[];
  analysis_text?: string;
  model_used?: string;
  _meta?: Record<string, any>;
  [key: string]: any; // Allow additional properties
}

export const imageToolSchema = z.object({
  app_target: z.string().optional().describe(
    "Optional. Specifies the capture target. Examples:\n" +
    "- Omitted/empty: All screens.\n" +
    "- 'screen:INDEX': Specific display (e.g., 'screen:0').\n" +
    "- 'frontmost': All windows of the current foreground app.\n" +
    "- 'AppName': All windows of 'AppName'.\n" +
    "- 'AppName:WINDOW_TITLE:Title': Window of 'AppName' with 'Title'.\n" +
    "- 'AppName:WINDOW_INDEX:Index': Window of 'AppName' at 'Index'."
  ),
  path: z.string().optional().describe(
    "Optional. Base absolute path for saving the image. " +
    "If 'format' is 'data' and 'path' is also given, image is saved AND Base64 data returned. " +
    "If 'question' is provided and 'path' is omitted, a temporary path is used for capture, and the file is deleted after analysis."
  ),
  question: z.string().optional().describe(
    "Optional. If provided, the captured image will be analyzed. " +
    "The server automatically selects an AI provider from 'PEEKABOO_AI_PROVIDERS'."
  ),
  format: z.enum(["png", "jpg", "data"]).optional().default("png").describe(
    "Output format. 'png' or 'jpg' save to 'path' (if provided). " +
    "'data' returns Base64 encoded PNG data inline; if 'path' is also given, saves a PNG file to 'path' too. " +
    "If 'path' is not given, 'format' defaults to 'data' behavior (inline PNG data returned)."
  ),
  capture_focus: z.enum(["background", "foreground"])
    .optional()
    .default("background")
    .describe(
      "Optional. Focus behavior. 'background' (default): capture without altering window focus. " +
      "'foreground': bring target to front before capture."
    ),
});

export type ImageInput = z.infer<typeof imageToolSchema>;

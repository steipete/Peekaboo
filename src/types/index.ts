import { Logger } from "pino";

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

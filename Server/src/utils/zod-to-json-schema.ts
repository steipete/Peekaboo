import { z } from "zod";

// Type for accessing internal Zod definitions
type ZodDefAny = z.ZodTypeAny & {
  _def?: {
    description?: string;
    checks?: Array<{ kind: string; value?: unknown; message?: string }>;
    type?: string;
    values?: readonly unknown[];
    innerType?: z.ZodTypeAny;
    schema?: z.ZodTypeAny;
    typeName?: string;
    defaultValue?: () => unknown;
  };
  description?: string;
};

// JSON Schema type definition
interface JSONSchema {
  type?: string | string[];
  properties?: Record<string, JSONSchema>;
  items?: JSONSchema;
  required?: string[];
  enum?: unknown[];
  const?: unknown;
  description?: string;
  default?: unknown;
  additionalProperties?: boolean | JSONSchema;
  anyOf?: JSONSchema[];
  allOf?: JSONSchema[];
  oneOf?: JSONSchema[];
  not?: JSONSchema;
  minimum?: number;
  maximum?: number;
  minLength?: number;
  maxLength?: number;
  minItems?: number;
  maxItems?: number;
  pattern?: string;
  format?: string;
  $ref?: string;
}

/**
 * Helper function to recursively unwrap Zod schema wrappers
 * This properly extracts descriptions from nested wrapper types
 */
function unwrapZodSchema(field: z.ZodTypeAny): {
  coreSchema: z.ZodTypeAny;
  description: string | undefined;
  hasDefault: boolean;
  defaultValue?: unknown;
} {
  const zodField = field as ZodDefAny;
  const description = zodField._def?.description || zodField.description;
  let hasDefault = false;
  let defaultValue: unknown;

  // Get typeName for reliable type checking
  const typeName = zodField._def?.typeName;

  // Handle wrapper types
  if (typeName === "ZodOptional") {
    const inner = unwrapZodSchema((field as any)._def.innerType);
    return {
      coreSchema: inner.coreSchema,
      description: description || inner.description,
      hasDefault: inner.hasDefault,
      defaultValue: inner.defaultValue,
    };
  }

  if (typeName === "ZodDefault") {
    hasDefault = true;
    defaultValue = (field as any)._def.defaultValue();
    const inner = unwrapZodSchema((field as any)._def.innerType);
    return {
      coreSchema: inner.coreSchema,
      description: description || inner.description,
      hasDefault: true,
      defaultValue,
    };
  }

  if (typeName === "ZodEffects") {
    const inner = unwrapZodSchema((field as any)._def.schema);
    return {
      coreSchema: inner.coreSchema,
      description: description || inner.description,
      hasDefault: inner.hasDefault,
      defaultValue: inner.defaultValue,
    };
  }

  // Return the core schema
  return { coreSchema: field, description, hasDefault, defaultValue };
}

/**
 * Convert Zod schema to JSON Schema format
 * This is a robust converter for common Zod types used in the tools
 */
export function zodToJsonSchema(schema: z.ZodTypeAny): JSONSchema {
  const { coreSchema, description: rootDescription, hasDefault, defaultValue } = unwrapZodSchema(schema);
  
  // Get the type name for reliable type checking
  const typeName = (coreSchema as any)._def?.typeName;

  // Handle ZodObject
  if (typeName === "ZodObject") {
    const shape = (coreSchema as any).shape;
    const properties: Record<string, JSONSchema> = {};
    const required: string[] = [];

    for (const [key, value] of Object.entries(shape)) {
      const fieldSchema = value as z.ZodTypeAny;
      const unwrapped = unwrapZodSchema(fieldSchema);

      // Check if field is optional or has a default
      const fieldTypeName = (fieldSchema as any)._def?.typeName;
      const isOptional = fieldTypeName === "ZodOptional" || 
                        fieldTypeName === "ZodDefault" || 
                        unwrapped.hasDefault;

      // Build JSON schema for the property
      const propertySchema = zodToJsonSchema(unwrapped.coreSchema);

      // Add description from unwrapping if not already present
      if (unwrapped.description && !propertySchema.description) {
        propertySchema.description = unwrapped.description;
      }

      // Add default value if available
      if (unwrapped.hasDefault && unwrapped.defaultValue !== undefined) {
        propertySchema.default = unwrapped.defaultValue;
      }

      properties[key] = propertySchema;

      // Add to required array if not optional and no default
      if (!isOptional && !unwrapped.hasDefault) {
        required.push(key);
      }
    }

    const jsonSchema: JSONSchema = {
      type: "object",
      properties,
    };

    if (required.length > 0) {
      jsonSchema.required = required;
    }

    if (rootDescription) {
      jsonSchema.description = rootDescription;
    }

    return jsonSchema;
  }

  // Handle ZodArray
  if (typeName === "ZodArray") {
    const jsonSchema: JSONSchema = {
      type: "array",
      items: zodToJsonSchema(coreSchema._def.type),
    };

    // Handle array constraints
    const zodArray = coreSchema as ZodDefAny;
    const minLength = zodArray._def?.minLength;
    if (minLength && typeof minLength === "object" && "value" in minLength &&
        typeof minLength.value === "number" && minLength.value > 0) {
      jsonSchema.minItems = minLength.value;
    }

    const maxLength = zodArray._def?.maxLength;
    if (maxLength && typeof maxLength === "object" && "value" in maxLength &&
        typeof maxLength.value === "number") {
      jsonSchema.maxItems = maxLength.value;
    }

    if (rootDescription) {
      jsonSchema.description = rootDescription;
    }

    if (hasDefault && defaultValue !== undefined) {
      jsonSchema.default = defaultValue;
    }

    return jsonSchema;
  }

  // Handle ZodString
  if (typeName === "ZodString") {
    const jsonSchema: JSONSchema = { type: "string" };
    if (rootDescription) {
      jsonSchema.description = rootDescription;
    }
    if (hasDefault && defaultValue !== undefined) {
      jsonSchema.default = defaultValue;
    }
    return jsonSchema;
  }

  // Handle ZodNumber
  if (typeName === "ZodNumber") {
    const jsonSchema: JSONSchema = { type: "number" };
    if (rootDescription) {
      jsonSchema.description = rootDescription;
    }
    // Check if it's an integer
    const checks = (coreSchema as any)._def?.checks || [];
    if (checks.some((check: any) => check.kind === "int")) {
      jsonSchema.type = "integer";
    }
    if (hasDefault && defaultValue !== undefined) {
      jsonSchema.default = defaultValue;
    }
    return jsonSchema;
  }

  // Handle ZodBoolean
  if (typeName === "ZodBoolean") {
    const jsonSchema: JSONSchema = { type: "boolean" };
    if (rootDescription) {
      jsonSchema.description = rootDescription;
    }
    if (hasDefault && defaultValue !== undefined) {
      jsonSchema.default = defaultValue;
    }
    return jsonSchema;
  }

  // Handle ZodEnum
  if (typeName === "ZodEnum") {
    const jsonSchema: JSONSchema = {
      type: "string",
      enum: coreSchema._def.values as unknown[],
    };
    if (rootDescription) {
      jsonSchema.description = rootDescription;
    }
    if (hasDefault && defaultValue !== undefined) {
      jsonSchema.default = defaultValue;
    }
    return jsonSchema;
  }

  // Handle ZodUnion
  if (typeName === "ZodUnion") {
    const jsonSchema: JSONSchema = {
      oneOf: coreSchema._def.options.map((option: z.ZodTypeAny) =>
        zodToJsonSchema(option),
      ),
    };
    if (rootDescription) {
      jsonSchema.description = rootDescription;
    }
    return jsonSchema;
  }

  // Handle ZodLiteral
  if (typeName === "ZodLiteral") {
    const value = coreSchema._def.value;
    const jsonSchema: JSONSchema = {};

    if (typeof value === "string") {
      jsonSchema.type = "string";
      jsonSchema.const = value;
    } else if (typeof value === "number") {
      jsonSchema.type = "number";
      jsonSchema.const = value;
    } else if (typeof value === "boolean") {
      jsonSchema.type = "boolean";
      jsonSchema.const = value;
    } else {
      // For other types, just use const
      jsonSchema.const = value;
    }

    if (rootDescription) {
      jsonSchema.description = rootDescription;
    }

    return jsonSchema;
  }

  // Fallback
  return { type: "string" }; // Default fallback for unknown types
}

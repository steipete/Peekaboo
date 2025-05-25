import { z } from "zod";

/**
 * Helper function to recursively unwrap Zod schema wrappers
 * This properly extracts descriptions from nested wrapper types
 */
function unwrapZodSchema(field: z.ZodTypeAny): { 
  coreSchema: z.ZodTypeAny; 
  description: string | undefined;
  hasDefault: boolean;
  defaultValue?: any;
} {
  let description = (field as any)._def?.description || (field as any).description;
  let hasDefault = false;
  let defaultValue: any;
  
  // Handle wrapper types
  if (field instanceof z.ZodOptional) {
    const inner = unwrapZodSchema(field._def.innerType);
    return {
      coreSchema: inner.coreSchema,
      description: description || inner.description,
      hasDefault: inner.hasDefault,
      defaultValue: inner.defaultValue,
    };
  }
  
  if (field instanceof z.ZodDefault) {
    hasDefault = true;
    defaultValue = field._def.defaultValue();
    const inner = unwrapZodSchema(field._def.innerType);
    return {
      coreSchema: inner.coreSchema,
      description: description || inner.description,
      hasDefault: true,
      defaultValue,
    };
  }
  
  if (field instanceof z.ZodEffects) {
    const inner = unwrapZodSchema(field._def.schema);
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
export function zodToJsonSchema(schema: z.ZodTypeAny): any {
  const { coreSchema, description: rootDescription, hasDefault, defaultValue } = unwrapZodSchema(schema);
  
  // Handle ZodObject
  if (coreSchema instanceof z.ZodObject) {
    const shape = coreSchema.shape;
    const properties: any = {};
    const required: string[] = [];

    for (const [key, value] of Object.entries(shape)) {
      const fieldSchema = value as z.ZodTypeAny;
      const unwrapped = unwrapZodSchema(fieldSchema);
      
      // Check if field is optional
      const isOptional = fieldSchema instanceof z.ZodOptional;
      
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

    const jsonSchema: any = {
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
  if (coreSchema instanceof z.ZodArray) {
    const jsonSchema: any = {
      type: "array",
      items: zodToJsonSchema(coreSchema._def.type),
    };
    
    // Handle array constraints
    const minLength = (coreSchema as any)._def.minLength;
    if (minLength?.value > 0) {
      jsonSchema.minItems = minLength.value;
    }
    
    const maxLength = (coreSchema as any)._def.maxLength;
    if (maxLength?.value !== undefined) {
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
  if (coreSchema instanceof z.ZodString) {
    const jsonSchema: any = { type: "string" };
    if (rootDescription) {
      jsonSchema.description = rootDescription;
    }
    if (hasDefault && defaultValue !== undefined) {
      jsonSchema.default = defaultValue;
    }
    return jsonSchema;
  }

  // Handle ZodNumber
  if (coreSchema instanceof z.ZodNumber) {
    const jsonSchema: any = { type: "number" };
    if (rootDescription) {
      jsonSchema.description = rootDescription;
    }
    if ((coreSchema as any).isInt) {
      jsonSchema.type = "integer";
    }
    if (hasDefault && defaultValue !== undefined) {
      jsonSchema.default = defaultValue;
    }
    return jsonSchema;
  }

  // Handle ZodBoolean
  if (coreSchema instanceof z.ZodBoolean) {
    const jsonSchema: any = { type: "boolean" };
    if (rootDescription) {
      jsonSchema.description = rootDescription;
    }
    if (hasDefault && defaultValue !== undefined) {
      jsonSchema.default = defaultValue;
    }
    return jsonSchema;
  }

  // Handle ZodEnum
  if (coreSchema instanceof z.ZodEnum) {
    const jsonSchema: any = {
      type: "string",
      enum: coreSchema._def.values,
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
  if (coreSchema instanceof z.ZodUnion) {
    const jsonSchema: any = {
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
  if (coreSchema instanceof z.ZodLiteral) {
    const value = coreSchema._def.value;
    const jsonSchema: any = {};

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
  return { type: "any" };
}

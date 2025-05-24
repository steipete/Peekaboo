import { z } from 'zod';

/**
 * Convert Zod schema to JSON Schema format
 * This is a simplified converter for common Zod types used in the tools
 */
export function zodToJsonSchema(schema: z.ZodTypeAny): any {
  // Handle ZodDefault first
  if (schema instanceof z.ZodDefault) {
    const jsonSchema = zodToJsonSchema(schema._def.innerType);
    jsonSchema.default = schema._def.defaultValue();
    return jsonSchema;
  }
  
  // Handle ZodOptional
  if (schema instanceof z.ZodOptional) {
    return zodToJsonSchema(schema._def.innerType);
  }
  
  if (schema instanceof z.ZodString) {
    const jsonSchema: any = { type: 'string' };
    if (schema.description) {
      jsonSchema.description = schema.description;
    }
    return jsonSchema;
  }
  
  if (schema instanceof z.ZodNumber) {
    const jsonSchema: any = { type: 'number' };
    if (schema.description) {
      jsonSchema.description = schema.description;
    }
    if (schema.isInt) {
      jsonSchema.type = 'integer';
    }
    return jsonSchema;
  }
  
  if (schema instanceof z.ZodBoolean) {
    const jsonSchema: any = { type: 'boolean' };
    if (schema.description) {
      jsonSchema.description = schema.description;
    }
    return jsonSchema;
  }
  
  if (schema instanceof z.ZodEnum) {
    const jsonSchema: any = {
      type: 'string',
      enum: schema._def.values
    };
    if (schema.description) {
      jsonSchema.description = schema.description;
    }
    return jsonSchema;
  }
  
  if (schema instanceof z.ZodArray) {
    const jsonSchema: any = {
      type: 'array',
      items: zodToJsonSchema(schema._def.type)
    };
    if (schema.description) {
      jsonSchema.description = schema.description;
    }
    return jsonSchema;
  }
  
  if (schema instanceof z.ZodObject) {
    const shape = schema.shape;
    const properties: any = {};
    const required: string[] = [];
    
    for (const [key, value] of Object.entries(shape)) {
      const fieldSchema = value as z.ZodTypeAny;
      properties[key] = zodToJsonSchema(fieldSchema);
      
      // Check if field is required (not optional and not default)
      if (!(fieldSchema instanceof z.ZodOptional) && !(fieldSchema instanceof z.ZodDefault)) {
        required.push(key);
      }
    }
    
    const jsonSchema: any = {
      type: 'object',
      properties
    };
    
    if (required.length > 0) {
      jsonSchema.required = required;
    }
    
    if (schema.description) {
      jsonSchema.description = schema.description;
    }
    
    return jsonSchema;
  }
  
  if (schema instanceof z.ZodUnion) {
    return {
      oneOf: schema._def.options.map((option: z.ZodTypeAny) => zodToJsonSchema(option))
    };
  }
  
  if (schema instanceof z.ZodLiteral) {
    const value = schema._def.value;
    const jsonSchema: any = {};
    
    if (typeof value === 'string') {
      jsonSchema.type = 'string';
      jsonSchema.const = value;
    } else if (typeof value === 'number') {
      jsonSchema.type = 'number';
      jsonSchema.const = value;
    } else if (typeof value === 'boolean') {
      jsonSchema.type = 'boolean';
      jsonSchema.const = value;
    } else {
      // For other types, just use const
      jsonSchema.const = value;
    }
    
    if (schema.description) {
      jsonSchema.description = schema.description;
    }
    
    return jsonSchema;
  }
  
  // Fallback
  return { type: 'any' };
}
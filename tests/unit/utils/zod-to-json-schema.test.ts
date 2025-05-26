import { z } from "zod";
import { zodToJsonSchema } from "../../../src/utils/zod-to-json-schema";

describe("zodToJsonSchema", () => {
  describe("primitive types", () => {
    test("converts ZodString to JSON Schema", () => {
      const schema = z.string();
      expect(zodToJsonSchema(schema)).toEqual({ type: "string" });
    });

    test("converts ZodString with description", () => {
      const schema = z.string().describe("A test string");
      expect(zodToJsonSchema(schema)).toEqual({
        type: "string",
        description: "A test string",
      });
    });

    test("converts ZodNumber to JSON Schema", () => {
      const schema = z.number();
      expect(zodToJsonSchema(schema)).toEqual({ type: "number" });
    });

    test("converts ZodNumber with description", () => {
      const schema = z.number().describe("A test number");
      expect(zodToJsonSchema(schema)).toEqual({
        type: "number",
        description: "A test number",
      });
    });

    test("converts ZodBoolean to JSON Schema", () => {
      const schema = z.boolean();
      expect(zodToJsonSchema(schema)).toEqual({ type: "boolean" });
    });

    test("converts ZodBoolean with description", () => {
      const schema = z.boolean().describe("A test boolean");
      expect(zodToJsonSchema(schema)).toEqual({
        type: "boolean",
        description: "A test boolean",
      });
    });
  });

  describe("enum types", () => {
    test("converts ZodEnum to JSON Schema", () => {
      const schema = z.enum(["option1", "option2", "option3"]);
      expect(zodToJsonSchema(schema)).toEqual({
        type: "string",
        enum: ["option1", "option2", "option3"],
      });
    });

    test("converts ZodEnum with description", () => {
      const schema = z.enum(["red", "green", "blue"]).describe("Color options");
      expect(zodToJsonSchema(schema)).toEqual({
        type: "string",
        enum: ["red", "green", "blue"],
        description: "Color options",
      });
    });
  });

  describe("array types", () => {
    test("converts ZodArray of strings to JSON Schema", () => {
      const schema = z.array(z.string());
      expect(zodToJsonSchema(schema)).toEqual({
        type: "array",
        items: { type: "string" },
      });
    });

    test("converts ZodArray with description", () => {
      const schema = z.array(z.number()).describe("Array of numbers");
      expect(zodToJsonSchema(schema)).toEqual({
        type: "array",
        items: { type: "number" },
        description: "Array of numbers",
      });
    });

    test("converts nested arrays", () => {
      const schema = z.array(z.array(z.boolean()));
      expect(zodToJsonSchema(schema)).toEqual({
        type: "array",
        items: {
          type: "array",
          items: { type: "boolean" },
        },
      });
    });
  });

  describe("object types", () => {
    test("converts simple ZodObject to JSON Schema", () => {
      const schema = z.object({
        name: z.string(),
        age: z.number(),
      });
      expect(zodToJsonSchema(schema)).toEqual({
        type: "object",
        properties: {
          name: { type: "string" },
          age: { type: "number" },
        },
        required: ["name", "age"],
      });
    });

    test("converts ZodObject with optional fields", () => {
      const schema = z.object({
        required: z.string(),
        optional: z.string().optional(),
      });
      expect(zodToJsonSchema(schema)).toEqual({
        type: "object",
        properties: {
          required: { type: "string" },
          optional: { type: "string" },
        },
        required: ["required"],
      });
    });

    test("converts ZodObject with default fields", () => {
      const schema = z.object({
        name: z.string(),
        status: z.string().default("active"),
      });
      expect(zodToJsonSchema(schema)).toEqual({
        type: "object",
        properties: {
          name: { type: "string" },
          status: { type: "string", default: "active" },
        },
        required: ["name"],
      });
    });

    test("converts nested objects", () => {
      const schema = z.object({
        user: z.object({
          name: z.string(),
          settings: z.object({
            theme: z.enum(["light", "dark"]),
          }),
        }),
      });
      expect(zodToJsonSchema(schema)).toEqual({
        type: "object",
        properties: {
          user: {
            type: "object",
            properties: {
              name: { type: "string" },
              settings: {
                type: "object",
                properties: {
                  theme: {
                    type: "string",
                    enum: ["light", "dark"],
                  },
                },
                required: ["theme"],
              },
            },
            required: ["name", "settings"],
          },
        },
        required: ["user"],
      });
    });

    test("converts ZodObject with description", () => {
      const schema = z
        .object({
          id: z.string(),
        })
        .describe("User object");
      expect(zodToJsonSchema(schema)).toEqual({
        type: "object",
        properties: {
          id: { type: "string" },
        },
        required: ["id"],
        description: "User object",
      });
    });
  });

  describe("union types", () => {
    test("converts ZodUnion to JSON Schema", () => {
      const schema = z.union([z.string(), z.number()]);
      expect(zodToJsonSchema(schema)).toEqual({
        oneOf: [{ type: "string" }, { type: "number" }],
      });
    });

    test("converts complex union types", () => {
      const schema = z.union([
        z.object({ type: z.literal("text"), value: z.string() }),
        z.object({ type: z.literal("number"), value: z.number() }),
      ]);
      expect(zodToJsonSchema(schema)).toEqual({
        oneOf: [
          {
            type: "object",
            properties: {
              type: { type: "string", const: "text" },
              value: { type: "string" },
            },
            required: ["type", "value"],
          },
          {
            type: "object",
            properties: {
              type: { type: "string", const: "number" },
              value: { type: "number" },
            },
            required: ["type", "value"],
          },
        ],
      });
    });
  });

  describe("literal types", () => {
    test("converts string literal", () => {
      const schema = z.literal("hello");
      expect(zodToJsonSchema(schema)).toEqual({
        type: "string",
        const: "hello",
      });
    });

    test("converts number literal", () => {
      const schema = z.literal(42);
      expect(zodToJsonSchema(schema)).toEqual({ type: "number", const: 42 });
    });

    test("converts boolean literal", () => {
      const schema = z.literal(true);
      expect(zodToJsonSchema(schema)).toEqual({ type: "boolean", const: true });
    });

    test("converts literal with description", () => {
      const schema = z.literal("active").describe("Status must be active");
      expect(zodToJsonSchema(schema)).toEqual({
        type: "string",
        const: "active",
        description: "Status must be active",
      });
    });
  });

  describe("modifier types", () => {
    test("handles ZodOptional correctly", () => {
      const schema = z.string().optional();
      expect(zodToJsonSchema(schema)).toEqual({ type: "string" });
    });

    test("handles ZodDefault correctly", () => {
      const schema = z.number().default(42);
      expect(zodToJsonSchema(schema)).toEqual({
        type: "number",
        default: 42,
      });
    });

    test("handles chained modifiers", () => {
      const schema = z.string().optional().default("default");
      const result = zodToJsonSchema(schema);
      expect(result).toEqual({
        type: "string",
        default: "default",
      });
    });
  });

  describe("edge cases", () => {
    test("handles unknown types with fallback", () => {
      // Create a custom Zod type that isn't handled
      const customSchema = z.any();
      expect(zodToJsonSchema(customSchema)).toEqual({ type: "string" });
    });

    test("handles deeply nested structures", () => {
      const schema = z.object({
        level1: z.object({
          level2: z.object({
            level3: z.array(
              z.object({
                value: z.string(),
              }),
            ),
          }),
        }),
      });

      expect(zodToJsonSchema(schema)).toEqual({
        type: "object",
        properties: {
          level1: {
            type: "object",
            properties: {
              level2: {
                type: "object",
                properties: {
                  level3: {
                    type: "array",
                    items: {
                      type: "object",
                      properties: {
                        value: { type: "string" },
                      },
                      required: ["value"],
                    },
                  },
                },
                required: ["level3"],
              },
            },
            required: ["level2"],
          },
        },
        required: ["level1"],
      });
    });

    test("handles complex real-world schema", () => {
      const schema = z.object({
        action: z.enum(["show", "hide", "toggle"]),
        bundleId: z.string().optional(),
        windowId: z.number().optional(),
        config: z
          .object({
            animationDuration: z.number().default(200),
            position: z.enum(["left", "right", "center"]).optional(),
          })
          .optional(),
      });

      expect(zodToJsonSchema(schema)).toEqual({
        type: "object",
        properties: {
          action: {
            type: "string",
            enum: ["show", "hide", "toggle"],
          },
          bundleId: { type: "string" },
          windowId: { type: "number" },
          config: {
            type: "object",
            properties: {
              animationDuration: {
                type: "number",
                default: 200,
              },
              position: {
                type: "string",
                enum: ["left", "right", "center"],
              },
            },
          },
        },
        required: ["action"],
      });
    });
  });
});

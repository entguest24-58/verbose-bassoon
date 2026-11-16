import { z } from "zod";
import type { Entity } from "./store/memoryStore";

const addressSchema = z.object({
  line1: z.string().trim().min(1),
  line2: z.string().trim().optional(),
  city: z.string().trim().min(1),
  state: z.string().trim().optional(),
  postalCode: z.string().trim().min(1),
  country: z.string().trim().length(2, "country must be an ISO 3166-1 alpha-2 code").toUpperCase(),
});

export const customerCreateSchema = z
  .object({
    email: z.string().trim().toLowerCase().email(),
    firstName: z.string().trim().min(1).max(100),
    lastName: z.string().trim().min(1).max(100),
    phone: z.string().trim().max(30).optional(),
    address: addressSchema.optional(),
  })
  .strict();

export const customerUpdateSchema = customerCreateSchema
  .partial()
  .strict()
  .refine((v) => Object.keys(v).length > 0, { message: "At least one field is required" });

export type CustomerInput = z.infer<typeof customerCreateSchema>;
export type Customer = Entity & CustomerInput;

export const productCreateSchema = z
  .object({
    sku: z.string().trim().min(1).max(64),
    name: z.string().trim().min(1).max(200),
    description: z.string().trim().max(5000).optional(),
    price: z.number().nonnegative().multipleOf(0.01, "price must have at most 2 decimal places"),
    currency: z.string().trim().length(3).toUpperCase().default("USD"),
    stock: z.number().int().nonnegative().default(0),
    category: z.string().trim().min(1).max(100).optional(),
    active: z.boolean().default(true),
  })
  .strict();

export const productUpdateSchema = productCreateSchema
  .partial()
  .strict()
  .refine((v) => Object.keys(v).length > 0, { message: "At least one field is required" });

export type ProductInput = z.infer<typeof productCreateSchema>;
export type Product = Entity & ProductInput;

export const paginationSchema = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

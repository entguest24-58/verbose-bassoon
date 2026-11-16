import { type Request, type Response, Router } from "express";
import { z } from "zod";
import { conflict, notFound } from "../errors";
import { type Product, paginationSchema, productCreateSchema, productUpdateSchema } from "../models";
import type { MemoryStore } from "../store/memoryStore";

const listQuerySchema = paginationSchema.extend({
  category: z.string().trim().optional(),
  q: z.string().trim().toLowerCase().optional(),
  active: z.enum(["true", "false"]).transform((v) => v === "true").optional(),
  minPrice: z.coerce.number().nonnegative().optional(),
  maxPrice: z.coerce.number().nonnegative().optional(),
});

export function productsRouter(store: MemoryStore<Product>): Router {
  const router = Router();

  const assertSkuFree = (sku: string, exceptId?: string) => {
    const existing = store.find((p) => p.sku === sku && p.id !== exceptId);
    if (existing) throw conflict(`A product with SKU ${sku} already exists`);
  };

  router.get("/", (req, res) => {
    const { limit, offset, category, q, active, minPrice, maxPrice } = listQuerySchema.parse(req.query);
    let items = store.list();
    if (category) items = items.filter((p) => p.category?.toLowerCase() === category.toLowerCase());
    if (active !== undefined) items = items.filter((p) => p.active === active);
    if (minPrice !== undefined) items = items.filter((p) => p.price >= minPrice);
    if (maxPrice !== undefined) items = items.filter((p) => p.price <= maxPrice);
    if (q) items = items.filter((p) => `${p.name} ${p.description ?? ""} ${p.sku}`.toLowerCase().includes(q));
    res.json({ data: items.slice(offset, offset + limit), total: items.length, limit, offset });
  });

  router.get("/:id", (req, res) => {
    const product = store.get(req.params.id);
    if (!product) throw notFound("Product", req.params.id);
    res.json(product);
  });

  router.post("/", (req, res) => {
    const input = productCreateSchema.parse(req.body);
    assertSkuFree(input.sku);
    const product = store.create(input);
    res.status(201).location(`${req.baseUrl}/${product.id}`).json(product);
  });

  const update = (fullReplace: boolean) => (req: Request, res: Response) => {
    const id = req.params.id;
    if (!store.get(id)) throw notFound("Product", id);
    const input = fullReplace ? productCreateSchema.parse(req.body) : productUpdateSchema.parse(req.body);
    if (input.sku) assertSkuFree(input.sku, id);
    const patch = fullReplace ? { description: undefined, category: undefined, ...input } : input;
    res.json(store.update(id, patch));
  };

  router.put("/:id", update(true));
  router.patch("/:id", update(false));

  router.delete("/:id", (req, res) => {
    if (!store.delete(req.params.id)) throw notFound("Product", req.params.id);
    res.status(204).end();
  });

  return router;
}

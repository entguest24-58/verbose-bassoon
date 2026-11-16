import { type Request, type Response, Router } from "express";
import { z } from "zod";
import { conflict, notFound } from "../errors";
import { type Customer, customerCreateSchema, customerUpdateSchema, paginationSchema } from "../models";
import type { MemoryStore } from "../store/memoryStore";

const listQuerySchema = paginationSchema.extend({
  email: z.string().trim().toLowerCase().optional(),
  q: z.string().trim().toLowerCase().optional(),
});

export function customersRouter(store: MemoryStore<Customer>): Router {
  const router = Router();

  const assertEmailFree = (email: string, exceptId?: string) => {
    const existing = store.find((c) => c.email === email && c.id !== exceptId);
    if (existing) throw conflict(`A customer with email ${email} already exists`);
  };

  router.get("/", (req, res) => {
    const { limit, offset, email, q } = listQuerySchema.parse(req.query);
    let items = store.list();
    if (email) items = items.filter((c) => c.email === email);
    if (q) items = items.filter((c) => `${c.firstName} ${c.lastName} ${c.email}`.toLowerCase().includes(q));
    res.json({ data: items.slice(offset, offset + limit), total: items.length, limit, offset });
  });

  router.get("/:id", (req, res) => {
    const customer = store.get(req.params.id);
    if (!customer) throw notFound("Customer", req.params.id);
    res.json(customer);
  });

  router.post("/", (req, res) => {
    const input = customerCreateSchema.parse(req.body);
    assertEmailFree(input.email);
    const customer = store.create(input);
    res.status(201).location(`${req.baseUrl}/${customer.id}`).json(customer);
  });

  const update = (fullReplace: boolean) => (req: Request, res: Response) => {
    const id = req.params.id;
    if (!store.get(id)) throw notFound("Customer", id);
    const input = fullReplace ? customerCreateSchema.parse(req.body) : customerUpdateSchema.parse(req.body);
    if (input.email) assertEmailFree(input.email, id);
    const patch = fullReplace ? { phone: undefined, address: undefined, ...input } : input;
    res.json(store.update(id, patch));
  };

  router.put("/:id", update(true));
  router.patch("/:id", update(false));

  router.delete("/:id", (req, res) => {
    if (!store.delete(req.params.id)) throw notFound("Customer", req.params.id);
    res.status(204).end();
  });

  return router;
}

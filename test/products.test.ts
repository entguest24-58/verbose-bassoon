import request from "supertest";
import { beforeEach, describe, expect, it } from "vitest";
import { createApp } from "../src/app";

const mug = { sku: "MUG-001", name: "Coffee Mug", price: 12.5, stock: 40, category: "Kitchen" };

describe("products API", () => {
  let app: ReturnType<typeof createApp>;
  beforeEach(() => {
    app = createApp();
  });

  it("creates a product with defaults and supports full CRUD", async () => {
    const created = await request(app).post("/api/products").send(mug).expect(201);
    expect(created.body).toMatchObject({ ...mug, currency: "USD", active: true });
    const id = created.body.id;

    await request(app).get(`/api/products/${id}`).expect(200, created.body);

    const patched = await request(app).patch(`/api/products/${id}`).send({ stock: 39 }).expect(200);
    expect(patched.body).toMatchObject({ stock: 39, price: 12.5, active: true });

    const replaced = await request(app)
      .put(`/api/products/${id}`)
      .send({ sku: "MUG-001", name: "Large Mug", price: 15 })
      .expect(200);
    expect(replaced.body).toMatchObject({ name: "Large Mug", price: 15, stock: 0, currency: "USD" });
    expect(replaced.body.category).toBeUndefined();

    await request(app).delete(`/api/products/${id}`).expect(204);
    await request(app).get(`/api/products/${id}`).expect(404);
  });

  it("validates price, stock and currency", async () => {
    await request(app).post("/api/products").send({ ...mug, price: -1 }).expect(400);
    await request(app).post("/api/products").send({ ...mug, price: 1.234 }).expect(400);
    await request(app).post("/api/products").send({ ...mug, stock: 1.5 }).expect(400);
    await request(app).post("/api/products").send({ ...mug, currency: "DOLLARS" }).expect(400);
    await request(app).post("/api/products").send({ ...mug, price: "12.50" }).expect(400);
  });

  it("enforces unique SKU", async () => {
    await request(app).post("/api/products").send(mug).expect(201);
    const res = await request(app).post("/api/products").send({ ...mug, name: "Other" }).expect(409);
    expect(res.body.error.code).toBe("conflict");
  });

  it("filters by category, active flag, price range and text", async () => {
    await request(app).post("/api/products").send(mug).expect(201);
    await request(app)
      .post("/api/products")
      .send({ sku: "TEE-001", name: "T-Shirt", price: 20, category: "Apparel", active: false })
      .expect(201);
    await request(app).post("/api/products").send({ sku: "PAN-001", name: "Frying Pan", price: 35, category: "kitchen" });

    const kitchen = await request(app).get("/api/products?category=Kitchen").expect(200);
    expect(kitchen.body.total).toBe(2);

    const active = await request(app).get("/api/products?active=false").expect(200);
    expect(active.body.data.map((p: { sku: string }) => p.sku)).toEqual(["TEE-001"]);

    const range = await request(app).get("/api/products?minPrice=15&maxPrice=30").expect(200);
    expect(range.body.data.map((p: { sku: string }) => p.sku)).toEqual(["TEE-001"]);

    const text = await request(app).get("/api/products?q=pan").expect(200);
    expect(text.body.total).toBe(1);
  });

  it("returns JSON errors for malformed bodies and unknown routes", async () => {
    const bad = await request(app).post("/api/products").set("Content-Type", "application/json").send("{oops").expect(400);
    expect(bad.body.error.code).toBe("invalid_json");
    await request(app).get("/api/orders").expect(404);
  });
});

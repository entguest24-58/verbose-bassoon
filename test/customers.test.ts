import request from "supertest";
import { beforeEach, describe, expect, it } from "vitest";
import { createApp } from "../src/app";

const alice = { email: "Alice@Example.com", firstName: "Alice", lastName: "Smith" };

describe("customers API", () => {
  let app: ReturnType<typeof createApp>;
  beforeEach(() => {
    app = createApp();
  });

  it("creates, reads, lists, updates and deletes a customer", async () => {
    const created = await request(app).post("/api/customers").send(alice).expect(201);
    expect(created.body).toMatchObject({ email: "alice@example.com", firstName: "Alice", lastName: "Smith" });
    expect(created.headers.location).toBe(`/api/customers/${created.body.id}`);
    const id = created.body.id;

    await request(app).get(`/api/customers/${id}`).expect(200, created.body);

    const list = await request(app).get("/api/customers").expect(200);
    expect(list.body).toMatchObject({ total: 1, limit: 20, offset: 0 });
    expect(list.body.data[0].id).toBe(id);

    const patched = await request(app).patch(`/api/customers/${id}`).send({ phone: "+1-555-0100" }).expect(200);
    expect(patched.body).toMatchObject({ phone: "+1-555-0100", firstName: "Alice", createdAt: created.body.createdAt });

    const replaced = await request(app)
      .put(`/api/customers/${id}`)
      .send({ email: "alice@example.com", firstName: "Alicia", lastName: "Smith" })
      .expect(200);
    expect(replaced.body.firstName).toBe("Alicia");
    expect(replaced.body.phone).toBeUndefined();

    await request(app).delete(`/api/customers/${id}`).expect(204);
    await request(app).get(`/api/customers/${id}`).expect(404);
    await request(app).delete(`/api/customers/${id}`).expect(404);
  });

  it("rejects invalid payloads with 400", async () => {
    const res = await request(app).post("/api/customers").send({ email: "not-an-email", firstName: "" }).expect(400);
    expect(res.body.error.code).toBe("validation_error");
    await request(app).post("/api/customers").send({ ...alice, role: "admin" }).expect(400);
  });

  it("rejects an empty PATCH body", async () => {
    const { body } = await request(app).post("/api/customers").send(alice).expect(201);
    await request(app).patch(`/api/customers/${body.id}`).send({}).expect(400);
  });

  it("enforces unique email (case-insensitive) on create and update", async () => {
    await request(app).post("/api/customers").send(alice).expect(201);
    await request(app).post("/api/customers").send({ ...alice, email: "alice@EXAMPLE.com" }).expect(409);
    const bob = await request(app)
      .post("/api/customers")
      .send({ email: "bob@example.com", firstName: "Bob", lastName: "Jones" })
      .expect(201);
    await request(app).patch(`/api/customers/${bob.body.id}`).send({ email: "alice@example.com" }).expect(409);
  });

  it("filters and paginates the list", async () => {
    for (const name of ["Ann", "Ben", "Cara"]) {
      await request(app)
        .post("/api/customers")
        .send({ email: `${name.toLowerCase()}@example.com`, firstName: name, lastName: "Test" })
        .expect(201);
    }
    const page = await request(app).get("/api/customers?limit=2&offset=1").expect(200);
    expect(page.body.total).toBe(3);
    expect(page.body.data.map((c: { firstName: string }) => c.firstName)).toEqual(["Ben", "Cara"]);

    const search = await request(app).get("/api/customers?q=car").expect(200);
    expect(search.body.data).toHaveLength(1);
    await request(app).get("/api/customers?limit=0").expect(400);
  });

  it("returns 404 for an unknown customer", async () => {
    await request(app).patch("/api/customers/missing").send({ firstName: "X" }).expect(404);
  });
});

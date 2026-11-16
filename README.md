# verbose-bassoon

TypeScript REST API for an e-commerce back office: **customer** and **product** CRUD.
Built with Express 4 and zod; data is held in memory (resets on restart).

## Run

```bash
npm install
npm run dev          # tsx watch, http://localhost:3000
# or
npm run build && npm start
npm test             # vitest + supertest
```

`PORT` sets the listen port (default `3000`).

## Endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/health` | Liveness check → `{ "status": "ok" }` |
| GET | `/api/customers` | List customers. Query: `limit` (1–100, default 20), `offset`, `email`, `q` (name/email search) |
| POST | `/api/customers` | Create a customer → `201` + `Location` header |
| GET | `/api/customers/:id` | Get one customer |
| PUT | `/api/customers/:id` | Replace a customer (omitted optional fields are cleared) |
| PATCH | `/api/customers/:id` | Partially update a customer |
| DELETE | `/api/customers/:id` | Delete a customer → `204` |
| GET | `/api/products` | List products. Query: `limit`, `offset`, `category`, `active` (`true`/`false`), `minPrice`, `maxPrice`, `q` (name/description/SKU search) |
| POST | `/api/products` | Create a product → `201` + `Location` header |
| GET | `/api/products/:id` | Get one product |
| PUT | `/api/products/:id` | Replace a product (defaults re-applied, omitted optional fields cleared) |
| PATCH | `/api/products/:id` | Partially update a product |
| DELETE | `/api/products/:id` | Delete a product → `204` |

List responses: `{ "data": [...], "total": n, "limit": 20, "offset": 0 }`.

### Customer

```json
{
  "email": "alice@example.com",
  "firstName": "Alice",
  "lastName": "Smith",
  "phone": "+1-555-0100",
  "address": { "line1": "1 Main St", "city": "Springfield", "postalCode": "12345", "country": "US" }
}
```

- `email`, `firstName`, `lastName` required; `email` is stored lower-cased and must be unique (`409` otherwise).
- `address.country` is an ISO 3166-1 alpha-2 code.

### Product

```json
{
  "sku": "MUG-001",
  "name": "Coffee Mug",
  "description": "12oz ceramic mug",
  "price": 12.5,
  "currency": "USD",
  "stock": 40,
  "category": "Kitchen",
  "active": true
}
```

- `sku`, `name`, `price` required; `sku` must be unique (`409` otherwise).
- `price` ≥ 0 with at most 2 decimals; `stock` is a non-negative integer (default `0`);
  `currency` is a 3-letter code (default `USD`); `active` defaults to `true`.

Every entity also carries server-set `id` (UUID), `createdAt` and `updatedAt`.

## Errors

All errors share one shape:

```json
{ "error": { "code": "validation_error", "message": "Request validation failed", "details": [{ "path": "email", "message": "Invalid email" }] } }
```

| Status | `code` | When |
|---|---|---|
| 400 | `validation_error` | Body or query fails validation, unknown fields, empty PATCH |
| 400 | `invalid_json` | Body is not valid JSON |
| 404 | `not_found` | Unknown id or route |
| 409 | `conflict` | Duplicate customer email or product SKU |
| 500 | `internal_error` | Unexpected failure |

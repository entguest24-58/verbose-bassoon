import express, { type Express } from "express";
import { errorHandler, HttpError } from "./errors";
import type { Customer, Product } from "./models";
import { customersRouter } from "./routes/customers";
import { productsRouter } from "./routes/products";
import { MemoryStore } from "./store/memoryStore";

export interface AppStores {
  customers: MemoryStore<Customer>;
  products: MemoryStore<Product>;
}

export function createApp(stores: AppStores = { customers: new MemoryStore(), products: new MemoryStore() }): Express {
  const app = express();
  app.disable("x-powered-by");
  app.use(express.json({ limit: "1mb" }));

  app.get("/health", (_req, res) => {
    res.json({ status: "ok" });
  });

  app.use("/api/customers", customersRouter(stores.customers));
  app.use("/api/products", productsRouter(stores.products));

  app.use((req, _res, next) => next(new HttpError(404, "not_found", `Route ${req.method} ${req.path} not found`)));
  app.use(errorHandler);
  return app;
}

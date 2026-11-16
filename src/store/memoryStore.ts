import { randomUUID } from "node:crypto";

export interface Entity {
  id: string;
  createdAt: string;
  updatedAt: string;
}

/** Simple in-memory collection. Swap for a database-backed implementation later. */
export class MemoryStore<T extends Entity> {
  private readonly items = new Map<string, T>();

  list(): T[] {
    return [...this.items.values()].sort((a, b) => a.createdAt.localeCompare(b.createdAt));
  }

  get(id: string): T | undefined {
    return this.items.get(id);
  }

  find(predicate: (item: T) => boolean): T | undefined {
    for (const item of this.items.values()) if (predicate(item)) return item;
    return undefined;
  }

  create(data: Omit<T, keyof Entity>): T {
    const now = new Date().toISOString();
    const item = { ...data, id: randomUUID(), createdAt: now, updatedAt: now } as T;
    this.items.set(item.id, item);
    return item;
  }

  update(id: string, patch: Partial<Omit<T, keyof Entity>>): T | undefined {
    const existing = this.items.get(id);
    if (!existing) return undefined;
    const updated = { ...existing, ...patch, id, createdAt: existing.createdAt, updatedAt: new Date().toISOString() };
    this.items.set(id, updated);
    return updated;
  }

  delete(id: string): boolean {
    return this.items.delete(id);
  }

  clear(): void {
    this.items.clear();
  }
}

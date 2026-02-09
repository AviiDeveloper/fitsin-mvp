export class TTLCache {
  #store = new Map();

  get(key) {
    const hit = this.#store.get(key);
    if (!hit) return null;
    if (Date.now() > hit.expiresAt) {
      return null;
    }
    return hit.value;
  }

  getStale(key, maxStaleMs) {
    const hit = this.#store.get(key);
    if (!hit) return null;
    if (Date.now() > hit.expiresAt + maxStaleMs) {
      this.#store.delete(key);
      return null;
    }
    return hit.value;
  }

  set(key, value, ttlMs) {
    this.#store.set(key, { value, expiresAt: Date.now() + ttlMs });
  }

  delete(key) {
    this.#store.delete(key);
  }

  clear() {
    this.#store.clear();
  }
}

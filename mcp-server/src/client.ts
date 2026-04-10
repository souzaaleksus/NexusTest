// HTTP client for the embedded DelphiTestAgent.
// Wraps fetch() with token header and error normalization.

export interface AgentClientOptions {
  url: string;
  token?: string;
  timeoutMs?: number;
}

export class AgentClient {
  constructor(private readonly opts: AgentClientOptions) {}

  private headers(): Record<string, string> {
    const h: Record<string, string> = {
      "Content-Type": "application/json",
    };
    if (this.opts.token) h["X-Agent-Token"] = this.opts.token;
    return h;
  }

  async request(path: string, method: "GET" | "POST", body?: unknown): Promise<unknown> {
    const controller = new AbortController();
    const timeout = setTimeout(
      () => controller.abort(),
      this.opts.timeoutMs ?? 10_000,
    );
    try {
      const res = await fetch(`${this.opts.url}${path}`, {
        method,
        headers: this.headers(),
        body: body !== undefined ? JSON.stringify(body) : undefined,
        signal: controller.signal,
      });
      const text = await res.text();
      let parsed: unknown = text;
      try {
        parsed = JSON.parse(text);
      } catch {
        // leave as text
      }
      if (!res.ok) {
        throw new Error(
          `Agent ${method} ${path} -> ${res.status}: ${JSON.stringify(parsed)}`,
        );
      }
      return parsed;
    } catch (err) {
      if ((err as Error).name === "AbortError") {
        throw new Error(
          `Agent request timed out after ${this.opts.timeoutMs ?? 10_000}ms`,
        );
      }
      throw err;
    } finally {
      clearTimeout(timeout);
    }
  }

  health() {
    return this.request("/health", "GET");
  }

  tree() {
    return this.request("/tree", "GET");
  }

  components() {
    return this.request("/components", "GET");
  }

  dump(componentName: string) {
    return this.request(`/dump/${encodeURIComponent(componentName)}`, "GET");
  }

  get(componentName: string, propertyName: string) {
    return this.request(
      `/get/${encodeURIComponent(componentName)}/${encodeURIComponent(propertyName)}`,
      "GET",
    );
  }

  set(componentName: string, propertyName: string, value: string) {
    return this.request("/set", "POST", {
      component: componentName,
      property: propertyName,
      value,
    });
  }

  click(componentName: string) {
    return this.request("/click", "POST", { component: componentName });
  }

  invoke(componentName: string, eventName: string) {
    return this.request("/invoke", "POST", {
      component: componentName,
      event: eventName,
    });
  }

  focus(componentName: string) {
    return this.request("/focus", "POST", { component: componentName });
  }

  sendkey(key: string) {
    return this.request("/sendkey", "POST", { key });
  }
}

#!/usr/bin/env node
// NexusTest MCP server — exposes the DelphiTestAgent HTTP API as MCP tools
// so Claude Code can drive any VCL application that has the agent embedded.

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { AgentClient } from "./client.js";

const AGENT_URL = process.env.DELPHI_AGENT_URL ?? "http://localhost:8765";
const AGENT_TOKEN = process.env.DELPHI_AGENT_TOKEN ?? "";
const TIMEOUT_MS = Number(process.env.DELPHI_AGENT_TIMEOUT ?? "10000");

const client = new AgentClient({
  url: AGENT_URL,
  token: AGENT_TOKEN || undefined,
  timeoutMs: TIMEOUT_MS,
});

const server = new Server(
  { name: "nexustest-mcp-delphi-agent", version: "0.1.0" },
  { capabilities: { tools: {} } },
);

const tools = [
  {
    name: "delphi_health",
    description: "Check whether the embedded Delphi test agent is reachable.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
  },
  {
    name: "delphi_components",
    description:
      "List all components visible in the currently loaded forms as Name:ClassName pairs. Cheap; use this as a starting point to discover what is on screen.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
  },
  {
    name: "delphi_dump",
    description:
      "Return the full serialized component tree (name, class, bounds, published properties, children) rooted at a given component. Omit 'component' to dump all live forms from Screen.Forms.",
    inputSchema: {
      type: "object",
      properties: {
        component: {
          type: "string",
          description:
            "Optional component Name to root the dump at. If omitted, all live forms are dumped.",
        },
      },
      additionalProperties: false,
    },
  },
  {
    name: "delphi_get",
    description:
      "Read a single published property of a component via RTTI. Returns value as string.",
    inputSchema: {
      type: "object",
      properties: {
        component: { type: "string" },
        property: { type: "string" },
      },
      required: ["component", "property"],
      additionalProperties: false,
    },
  },
  {
    name: "delphi_set",
    description:
      "Set a published property via RTTI TypInfo.SetPropValue. Supports strings, integers, booleans, enums.",
    inputSchema: {
      type: "object",
      properties: {
        component: { type: "string" },
        property: { type: "string" },
        value: { type: "string" },
      },
      required: ["component", "property", "value"],
      additionalProperties: false,
    },
  },
  {
    name: "delphi_click",
    description:
      "Invoke OnClick of the named component on the main VCL thread. Equivalent to a user click but bypasses hit-testing so it works for non-focusable controls like TSpeedButton.",
    inputSchema: {
      type: "object",
      properties: { component: { type: "string" } },
      required: ["component"],
      additionalProperties: false,
    },
  },
  {
    name: "delphi_invoke",
    description:
      "Invoke any TNotifyEvent published by a component (OnExit, OnEnter, OnChange, OnDblClick, etc.).",
    inputSchema: {
      type: "object",
      properties: {
        component: { type: "string" },
        event: {
          type: "string",
          description: "Event name including the 'On' prefix, e.g. OnExit.",
        },
      },
      required: ["component", "event"],
      additionalProperties: false,
    },
  },
  {
    name: "delphi_focus",
    description: "Set focus to the named TWinControl descendant.",
    inputSchema: {
      type: "object",
      properties: { component: { type: "string" } },
      required: ["component"],
      additionalProperties: false,
    },
  },
  {
    name: "delphi_sendkey",
    description:
      "Post a WM_KEYDOWN/WM_KEYUP pair to the focused control. Use single characters or VK names like VK_RETURN, VK_TAB, VK_F5.",
    inputSchema: {
      type: "object",
      properties: { key: { type: "string" } },
      required: ["key"],
      additionalProperties: false,
    },
  },
];

server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools }));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const name = req.params.name;
  const args = (req.params.arguments ?? {}) as Record<string, string>;
  try {
    let result: unknown;
    switch (name) {
      case "delphi_health":
        result = await client.health();
        break;
      case "delphi_components":
        result = await client.components();
        break;
      case "delphi_dump":
        result = args.component ? await client.dump(args.component) : await client.tree();
        break;
      case "delphi_get":
        result = await client.get(args.component, args.property);
        break;
      case "delphi_set":
        result = await client.set(args.component, args.property, args.value);
        break;
      case "delphi_click":
        result = await client.click(args.component);
        break;
      case "delphi_invoke":
        result = await client.invoke(args.component, args.event);
        break;
      case "delphi_focus":
        result = await client.focus(args.component);
        break;
      case "delphi_sendkey":
        result = await client.sendkey(args.key);
        break;
      default:
        throw new Error(`Unknown tool: ${name}`);
    }
    return {
      content: [
        { type: "text", text: typeof result === "string" ? result : JSON.stringify(result, null, 2) },
      ],
    };
  } catch (err) {
    return {
      isError: true,
      content: [{ type: "text", text: `ERROR: ${(err as Error).message}` }],
    };
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);
console.error(`[nexustest-mcp] agent=${AGENT_URL} connected`);

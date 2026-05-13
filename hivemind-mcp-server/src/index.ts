import http from "node:http";
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { SSEServerTransport } from "@modelcontextprotocol/sdk/server/sse.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

const API_KEY = process.env.HIVEMIND_API_KEY;
const MACHINE_NAME = process.env.MACHINE_NAME ?? "unknown";
const BIND_HOST = process.env.BIND_HOST ?? "0.0.0.0";
const PORT = process.env.PORT ? parseInt(process.env.PORT, 10) : null;

// ---------------------------------------------------------------------------
// Shared in-process state — persists for the server process lifetime
// ---------------------------------------------------------------------------

interface MemoryEntry {
  value: string;
  timestamp: number;
  author?: string;
  machine?: string;
}

interface LogEntry {
  message: string;
  timestamp: number;
  author?: string;
  machine?: string;
}

interface Message {
  id: string;
  from?: string;
  to?: string;
  content: string;
  timestamp: number;
  machine?: string;
  read: boolean;
}

const sharedMemory = new Map<string, MemoryEntry>();
const sharedLog: LogEntry[] = [];
const messageQueue: Message[] = [];
let messageCounter = 0;

// ---------------------------------------------------------------------------
// Server factory — each SSE connection gets its own Server instance but they
// all read/write the module-level state above.
// ---------------------------------------------------------------------------

function makeServer(): Server {
  const server = new Server(
    { name: "hivemind-mcp-server", version: "1.0.0" },
    { capabilities: { tools: {} } }
  );

  server.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools: [
      {
        name: "set_memory",
        description: "Store a value in shared memory under a key",
        inputSchema: {
          type: "object",
          properties: {
            key: { type: "string", description: "Key to store the value under" },
            value: { type: "string", description: "Value to store" },
            author: { type: "string", description: "Optional agent identifier" },
          },
          required: ["key", "value"],
        },
      },
      {
        name: "get_memory",
        description: "Retrieve a value from shared memory by key",
        inputSchema: {
          type: "object",
          properties: {
            key: { type: "string" },
          },
          required: ["key"],
        },
      },
      {
        name: "list_memory",
        description: "List all keys in shared memory with metadata",
        inputSchema: {
          type: "object",
          properties: {
            prefix: { type: "string", description: "Optional key prefix filter" },
          },
        },
      },
      {
        name: "delete_memory",
        description: "Delete a key from shared memory",
        inputSchema: {
          type: "object",
          properties: {
            key: { type: "string" },
          },
          required: ["key"],
        },
      },
      {
        name: "append_log",
        description: "Append a message to the shared log",
        inputSchema: {
          type: "object",
          properties: {
            message: { type: "string" },
            author: { type: "string", description: "Optional agent identifier" },
          },
          required: ["message"],
        },
      },
      {
        name: "read_log",
        description: "Read entries from the shared log",
        inputSchema: {
          type: "object",
          properties: {
            limit: { type: "number", description: "Max entries to return (default 50)" },
            since: { type: "number", description: "Unix ms timestamp — only return entries after this" },
          },
        },
      },
      {
        name: "send_message",
        description: "Send a message to a specific agent or broadcast to all",
        inputSchema: {
          type: "object",
          properties: {
            content: { type: "string" },
            from: { type: "string", description: "Sender identifier" },
            to: { type: "string", description: "Recipient identifier (omit to broadcast)" },
          },
          required: ["content"],
        },
      },
      {
        name: "get_messages",
        description: "Retrieve pending messages addressed to an agent",
        inputSchema: {
          type: "object",
          properties: {
            recipient: { type: "string", description: "Your agent identifier" },
            mark_read: { type: "boolean", description: "Mark messages read (default true)" },
          },
          required: ["recipient"],
        },
      },
      {
        name: "clear_messages",
        description: "Remove all read messages from the queue",
        inputSchema: { type: "object", properties: {} },
      },
    ],
  }));

  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;

    switch (name) {
      case "set_memory": {
        const { key, value, author } = args as { key: string; value: string; author?: string };
        sharedMemory.set(key, { value, timestamp: Date.now(), author, machine: MACHINE_NAME });
        return { content: [{ type: "text", text: `Stored "${key}" in shared memory.` }] };
      }

      case "get_memory": {
        const { key } = args as { key: string };
        const entry = sharedMemory.get(key);
        if (!entry) return { content: [{ type: "text", text: `Key "${key}" not found.` }] };
        return { content: [{ type: "text", text: JSON.stringify({ key, ...entry }, null, 2) }] };
      }

      case "list_memory": {
        const { prefix } = ((args ?? {}) as { prefix?: string });
        const entries = [];
        for (const [key, e] of sharedMemory) {
          if (!prefix || key.startsWith(prefix)) {
            entries.push({ key, timestamp: e.timestamp, author: e.author, machine: e.machine });
          }
        }
        return {
          content: [{
            type: "text",
            text: entries.length === 0 ? "Shared memory is empty." : JSON.stringify(entries, null, 2),
          }],
        };
      }

      case "delete_memory": {
        const { key } = args as { key: string };
        const existed = sharedMemory.delete(key);
        return { content: [{ type: "text", text: existed ? `Deleted "${key}".` : `Key "${key}" not found.` }] };
      }

      case "append_log": {
        const { message, author } = args as { message: string; author?: string };
        sharedLog.push({ message, timestamp: Date.now(), author, machine: MACHINE_NAME });
        return { content: [{ type: "text", text: "Log entry appended." }] };
      }

      case "read_log": {
        const { limit = 50, since } = ((args ?? {}) as { limit?: number; since?: number });
        let entries = since ? sharedLog.filter((e) => e.timestamp > since) : sharedLog;
        entries = entries.slice(-limit);
        return {
          content: [{
            type: "text",
            text: entries.length === 0 ? "No log entries." : JSON.stringify(entries, null, 2),
          }],
        };
      }

      case "send_message": {
        const { content, from, to } = args as { content: string; from?: string; to?: string };
        const id = `msg-${++messageCounter}`;
        messageQueue.push({ id, from, to, content, timestamp: Date.now(), machine: MACHINE_NAME, read: false });
        return {
          content: [{
            type: "text",
            text: to ? `Message ${id} sent to "${to}".` : `Message ${id} broadcast.`,
          }],
        };
      }

      case "get_messages": {
        const { recipient, mark_read = true } = args as { recipient: string; mark_read?: boolean };
        const messages = messageQueue.filter((m) => !m.read && (!m.to || m.to === recipient));
        if (mark_read) messages.forEach((m) => { m.read = true; });
        return {
          content: [{
            type: "text",
            text: messages.length === 0 ? "No pending messages." : JSON.stringify(messages, null, 2),
          }],
        };
      }

      case "clear_messages": {
        const removed = messageQueue.filter((m) => m.read).length;
        messageQueue.splice(0, messageQueue.length, ...messageQueue.filter((m) => !m.read));
        return {
          content: [{
            type: "text",
            text: `Cleared ${removed} read messages (${messageQueue.length} unread remain).`,
          }],
        };
      }

      default:
        return { content: [{ type: "text", text: `Unknown tool: ${name}` }], isError: true };
    }
  });

  return server;
}

// ---------------------------------------------------------------------------
// Auth helper
// ---------------------------------------------------------------------------

function isAuthorized(req: http.IncomingMessage): boolean {
  if (!API_KEY) return true;
  const auth = req.headers["authorization"];
  const headerKey = auth?.startsWith("Bearer ") ? auth.slice(7) : (req.headers["x-api-key"] as string | undefined);
  return headerKey === API_KEY;
}

// ---------------------------------------------------------------------------
// HTTP / SSE mode
// ---------------------------------------------------------------------------

async function startHttp(): Promise<void> {
  const sessions = new Map<string, SSEServerTransport>();

  const httpServer = http.createServer(async (req, res) => {
    if (!isAuthorized(req)) {
      res.writeHead(401, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "Unauthorized" }));
      return;
    }

    const url = new URL(req.url ?? "/", `http://${req.headers.host ?? "localhost"}`);

    if (req.method === "GET" && url.pathname === "/sse") {
      const transport = new SSEServerTransport("/message", res);
      const server = makeServer();
      sessions.set(transport.sessionId, transport);
      transport.onclose = () => sessions.delete(transport.sessionId);
      await server.connect(transport);
      return;
    }

    if (req.method === "POST" && url.pathname === "/message") {
      const sessionId = url.searchParams.get("sessionId") ?? "";
      const transport = sessions.get(sessionId);
      if (!transport) {
        res.writeHead(404, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "Session not found" }));
        return;
      }
      await transport.handlePostMessage(req, res);
      return;
    }

    if (req.method === "GET" && url.pathname === "/health") {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ status: "ok", machine: MACHINE_NAME, sessions: sessions.size }));
      return;
    }

    res.writeHead(404);
    res.end("Not found");
  });

  await new Promise<void>((resolve) => {
    httpServer.listen(PORT!, BIND_HOST, () => {
      log(`Hivemind MCP server [${MACHINE_NAME}] listening on http://${BIND_HOST}:${PORT}`);
      log(`SSE endpoint: http://${BIND_HOST}:${PORT}/sse`);
      if (API_KEY) log("API key authentication enabled.");
      resolve();
    });
  });
}

// ---------------------------------------------------------------------------
// Stdio mode
// ---------------------------------------------------------------------------

async function startStdio(): Promise<void> {
  const transport = new StdioServerTransport();
  await makeServer().connect(transport);
  log(`Hivemind MCP server [${MACHINE_NAME}] running on stdio`);
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

function log(msg: string): void {
  process.stderr.write(`${msg}\n`);
}

(PORT ? startHttp() : startStdio()).catch((err) => {
  log(`Fatal: ${err}`);
  process.exit(1);
});

/**
 * HIVEMIND MCP SERVER
 *
 * PRIME DIRECTIVE:
 * Any device — Android phone, laptop, or desktop — can connect to this server
 * over Tailscale and share or offload processing with any other device in the
 * network. No device is locked to a single role. Every device is both a
 * potential client and a potential worker.
 *
 * Architecture:
 *   - One machine runs this server (typically the desktop hub).
 *   - All other devices (laptop, Android, etc.) connect to it via Tailscale IP.
 *   - Shared memory, log, and messaging are visible to every connected session.
 *   - MCP endpoint: http://<TAILSCALE_IP>:<PORT>/mcp
 *   - Auth:         Bearer <HIVEMIND_API_KEY>
 *
 * Environment variables:
 *   HIVEMIND_API_KEY  Required shared secret for all clients
 *   MACHINE_NAME      Human label for this host (e.g. "hivemind-desktop")
 *   BIND_HOST         IP to bind (use Tailscale IP, e.g. 100.x.x.x)
 *   PORT              Port to listen on (e.g. 3737)
 */

import http from "node:http";
import { randomUUID } from "node:crypto";
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

const API_KEY     = process.env.HIVEMIND_API_KEY;
const MACHINE_NAME = process.env.MACHINE_NAME ?? "unknown";
const BIND_HOST   = process.env.BIND_HOST ?? "0.0.0.0";
const PORT        = process.env.PORT ? parseInt(process.env.PORT, 10) : null;

// ---------------------------------------------------------------------------
// Shared state — all connected sessions read and write the same data,
// regardless of which physical device they originate from.
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
// MCP server factory — one Server instance per connection; all share state.
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
        description:
          "Store a value in shared memory — visible to all connected devices",
        inputSchema: {
          type: "object",
          properties: {
            key:    { type: "string", description: "Key to store the value under" },
            value:  { type: "string", description: "Value to store" },
            author: { type: "string", description: "Optional agent/device identifier" },
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
        description:
          "Append a timestamped entry to the shared log — readable by all devices",
        inputSchema: {
          type: "object",
          properties: {
            message: { type: "string" },
            author:  { type: "string", description: "Optional agent/device identifier" },
          },
          required: ["message"],
        },
      },
      {
        name: "read_log",
        description: "Read recent entries from the shared log",
        inputSchema: {
          type: "object",
          properties: {
            limit: { type: "number", description: "Max entries to return (default 50)" },
            since: { type: "number", description: "Unix ms timestamp — only entries after this" },
          },
        },
      },
      {
        name: "send_message",
        description:
          "Send a message to a specific device/agent, or broadcast to all",
        inputSchema: {
          type: "object",
          properties: {
            content: { type: "string" },
            from:    { type: "string", description: "Sender identifier (e.g. 'android', 'laptop')" },
            to:      { type: "string", description: "Recipient identifier — omit to broadcast" },
          },
          required: ["content"],
        },
      },
      {
        name: "get_messages",
        description: "Retrieve pending messages addressed to this device/agent",
        inputSchema: {
          type: "object",
          properties: {
            recipient: { type: "string", description: "Your device/agent identifier" },
            mark_read: { type: "boolean", description: "Mark retrieved messages as read (default true)" },
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
            text: to ? `Message ${id} sent to "${to}".` : `Message ${id} broadcast to all devices.`,
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
// Auth
// ---------------------------------------------------------------------------

function isAuthorized(req: http.IncomingMessage): boolean {
  if (!API_KEY) return true;
  const auth = req.headers["authorization"];
  const key = auth?.startsWith("Bearer ") ? auth.slice(7) : (req.headers["x-api-key"] as string | undefined);
  return key === API_KEY;
}

// ---------------------------------------------------------------------------
// HTTP mode — serves the /mcp endpoint for all Tailscale-connected devices
// ---------------------------------------------------------------------------

async function startHttp(): Promise<void> {
  const sessions = new Map<string, StreamableHTTPServerTransport>();

  const httpServer = http.createServer(async (req, res) => {
    if (!isAuthorized(req)) {
      res.writeHead(401, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "Unauthorized" }));
      return;
    }

    const url = new URL(req.url ?? "/", `http://${req.headers.host ?? "localhost"}`);

    // Health check — useful for verifying Tailscale connectivity from any device
    if (req.method === "GET" && url.pathname === "/health") {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ status: "ok", machine: MACHINE_NAME, uptime: process.uptime() }));
      return;
    }

    // MCP endpoint — all devices connect here
    if (url.pathname === "/mcp") {
      const sessionId = req.headers["mcp-session-id"] as string | undefined;

      // Route to existing session if present
      if (sessionId && sessions.has(sessionId)) {
        await sessions.get(sessionId)!.handleRequest(req, res);
        return;
      }

      // New session — only allow on initialize (POST with no session ID)
      const transport = new StreamableHTTPServerTransport({
        sessionIdGenerator: () => randomUUID(),
      });
      const server = makeServer();

      transport.onclose = () => {
        if (transport.sessionId) sessions.delete(transport.sessionId);
      };

      await server.connect(transport);
      await transport.handleRequest(req, res);

      // Store after handling so session ID is populated
      if (transport.sessionId) sessions.set(transport.sessionId, transport);
      return;
    }

    res.writeHead(404);
    res.end("Not found");
  });

  await new Promise<void>((resolve) => {
    httpServer.listen(PORT!, BIND_HOST, () => {
      log(`Hivemind MCP server [${MACHINE_NAME}] listening on http://${BIND_HOST}:${PORT}`);
      log(`MCP endpoint : http://${BIND_HOST}:${PORT}/mcp`);
      log(`Health check : http://${BIND_HOST}:${PORT}/health`);
      if (API_KEY) log("API key authentication: enabled");
      resolve();
    });
  });
}

// ---------------------------------------------------------------------------
// Stdio mode — fallback for local Claude Code usage without HTTP
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

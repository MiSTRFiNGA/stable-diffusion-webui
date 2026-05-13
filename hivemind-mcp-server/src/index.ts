import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

interface MemoryEntry {
  value: string;
  timestamp: number;
  author?: string;
}

interface LogEntry {
  message: string;
  timestamp: number;
  author?: string;
}

interface Message {
  id: string;
  from?: string;
  to?: string;
  content: string;
  timestamp: number;
  read: boolean;
}

// In-process shared state (persists for the lifetime of the server process)
const sharedMemory = new Map<string, MemoryEntry>();
const sharedLog: LogEntry[] = [];
const messageQueue: Message[] = [];
let messageCounter = 0;

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
          key: { type: "string", description: "The key to store the value under" },
          value: { type: "string", description: "The value to store" },
          author: { type: "string", description: "Optional identifier of the agent writing this" },
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
          key: { type: "string", description: "The key to retrieve" },
        },
        required: ["key"],
      },
    },
    {
      name: "list_memory",
      description: "List all keys in shared memory with their metadata",
      inputSchema: {
        type: "object",
        properties: {
          prefix: { type: "string", description: "Optional prefix to filter keys" },
        },
      },
    },
    {
      name: "delete_memory",
      description: "Delete a key from shared memory",
      inputSchema: {
        type: "object",
        properties: {
          key: { type: "string", description: "The key to delete" },
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
          message: { type: "string", description: "The log message" },
          author: { type: "string", description: "Optional identifier of the agent writing this" },
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
          limit: { type: "number", description: "Max number of entries to return (default 50)" },
          since: { type: "number", description: "Unix timestamp in ms — return only entries after this time" },
        },
      },
    },
    {
      name: "send_message",
      description: "Send a message to a specific agent or broadcast to all",
      inputSchema: {
        type: "object",
        properties: {
          content: { type: "string", description: "The message content" },
          from: { type: "string", description: "Sender identifier" },
          to: { type: "string", description: "Recipient identifier (omit to broadcast)" },
        },
        required: ["content"],
      },
    },
    {
      name: "get_messages",
      description: "Retrieve pending messages for an agent",
      inputSchema: {
        type: "object",
        properties: {
          recipient: { type: "string", description: "Your agent identifier (gets messages addressed to you or broadcast)" },
          mark_read: { type: "boolean", description: "Mark retrieved messages as read (default true)" },
        },
        required: ["recipient"],
      },
    },
    {
      name: "clear_messages",
      description: "Clear all read messages from the queue",
      inputSchema: {
        type: "object",
        properties: {},
      },
    },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  switch (name) {
    case "set_memory": {
      const { key, value, author } = args as { key: string; value: string; author?: string };
      sharedMemory.set(key, { value, timestamp: Date.now(), author });
      return { content: [{ type: "text", text: `Stored key "${key}" in shared memory.` }] };
    }

    case "get_memory": {
      const { key } = args as { key: string };
      const entry = sharedMemory.get(key);
      if (!entry) {
        return { content: [{ type: "text", text: `Key "${key}" not found in shared memory.` }] };
      }
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              key,
              value: entry.value,
              timestamp: entry.timestamp,
              author: entry.author,
            }, null, 2),
          },
        ],
      };
    }

    case "list_memory": {
      const { prefix } = (args ?? {}) as { prefix?: string };
      const entries: Array<{ key: string; timestamp: number; author?: string }> = [];
      for (const [key, entry] of sharedMemory) {
        if (!prefix || key.startsWith(prefix)) {
          entries.push({ key, timestamp: entry.timestamp, author: entry.author });
        }
      }
      return {
        content: [
          {
            type: "text",
            text: entries.length === 0
              ? "Shared memory is empty."
              : JSON.stringify(entries, null, 2),
          },
        ],
      };
    }

    case "delete_memory": {
      const { key } = args as { key: string };
      const existed = sharedMemory.delete(key);
      return {
        content: [
          {
            type: "text",
            text: existed ? `Deleted key "${key}" from shared memory.` : `Key "${key}" not found.`,
          },
        ],
      };
    }

    case "append_log": {
      const { message, author } = args as { message: string; author?: string };
      sharedLog.push({ message, timestamp: Date.now(), author });
      return { content: [{ type: "text", text: "Log entry appended." }] };
    }

    case "read_log": {
      const { limit = 50, since } = (args ?? {}) as { limit?: number; since?: number };
      let entries = since ? sharedLog.filter((e) => e.timestamp > since) : sharedLog;
      entries = entries.slice(-limit);
      return {
        content: [
          {
            type: "text",
            text: entries.length === 0
              ? "No log entries."
              : JSON.stringify(entries, null, 2),
          },
        ],
      };
    }

    case "send_message": {
      const { content, from, to } = args as { content: string; from?: string; to?: string };
      const id = `msg-${++messageCounter}`;
      messageQueue.push({ id, from, to, content, timestamp: Date.now(), read: false });
      return {
        content: [
          {
            type: "text",
            text: to
              ? `Message ${id} sent to "${to}".`
              : `Message ${id} broadcast to all agents.`,
          },
        ],
      };
    }

    case "get_messages": {
      const { recipient, mark_read = true } = args as { recipient: string; mark_read?: boolean };
      const messages = messageQueue.filter(
        (m) => !m.read && (!m.to || m.to === recipient)
      );
      if (mark_read) {
        for (const m of messages) {
          m.read = true;
        }
      }
      return {
        content: [
          {
            type: "text",
            text: messages.length === 0
              ? "No pending messages."
              : JSON.stringify(messages, null, 2),
          },
        ],
      };
    }

    case "clear_messages": {
      const before = messageQueue.length;
      const removed = messageQueue.filter((m) => m.read).length;
      messageQueue.splice(0, messageQueue.length, ...messageQueue.filter((m) => !m.read));
      return {
        content: [{ type: "text", text: `Cleared ${removed} read messages (${messageQueue.length} unread remain).` }],
      };
    }

    default:
      return { content: [{ type: "text", text: `Unknown tool: ${name}` }], isError: true };
  }
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  process.stderr.write("Hivemind MCP server running on stdio\n");
}

main().catch((err) => {
  process.stderr.write(`Fatal error: ${err}\n`);
  process.exit(1);
});

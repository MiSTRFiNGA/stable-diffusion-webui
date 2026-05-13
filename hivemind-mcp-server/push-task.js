const { Client } = require("@modelcontextprotocol/sdk/client/index.js");
const { StreamableHTTPClientTransport } = require("@modelcontextprotocol/sdk/client/streamableHttp.js");

const API_KEY = process.env.HIVEMIND_API_KEY || "hivemind-key";
const HOST    = process.env.HIVEMIND_HOST    || "http://localhost:3737";

async function main() {
  const client = new Client({ name: "task-pusher", version: "1.0.0" });

  const transport = new StreamableHTTPClientTransport(
    new URL(`${HOST}/mcp`),
    { requestInit: { headers: { Authorization: `Bearer ${API_KEY}` } } }
  );

  await client.connect(transport);

  const key   = process.argv[2];
  const value = process.argv[3];

  if (!key || !value) {
    console.error("Usage: node push-task.js <key> <value>");
    process.exit(1);
  }

  const result = await client.callTool({ name: "set_memory", arguments: { key, value, author: "mobile-claude" } });
  console.log("Stored:", result.content[0].text);

  // Also append to log so desktop Claude sees it
  await client.callTool({ name: "append_log", arguments: { message: `TASK QUEUED [${key}]: ${value.slice(0, 80)}...`, author: "mobile-claude" } });
  console.log("Log updated.");

  await client.close();
}

main().catch(err => { console.error(err.message); process.exit(1); });

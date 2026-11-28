import assert from "node:assert/strict";
import test from "node:test";
import { readBoundedJson } from "../src/lib/bounded-json.ts";

test("readBoundedJson parses bounded JSON", async () => {
  const request = new Request("http://localhost/api", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ email: "adult@example.com" }),
  });
  assert.deepEqual(await readBoundedJson(request), { email: "adult@example.com" });
});

test("readBoundedJson cancels an oversized streamed body before reading more", async () => {
  let reads = 0;
  let canceled = false;
  const body = new ReadableStream({
    pull(controller) {
      reads += 1;
      controller.enqueue(new Uint8Array(10_001));
    },
    cancel() { canceled = true; },
  });
  const request = new Request("http://localhost/api", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body,
    duplex: "half",
  });

  await assert.rejects(readBoundedJson(request), /Request too large/);
  assert.equal(reads, 1);
  assert.equal(canceled, true);
});

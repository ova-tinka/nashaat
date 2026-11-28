const MAX_REQUEST_BYTES = 10_000;

export async function readBoundedJson(request: Request): Promise<unknown> {
  if (!request.headers.get("content-type")?.toLowerCase().includes("application/json")) {
    throw new Error("Expected JSON");
  }

  const declaredLength = request.headers.get("content-length");
  if (declaredLength !== null) {
    const length = Number(declaredLength);
    if (!Number.isSafeInteger(length) || length < 0) throw new Error("Invalid content length");
    if (length > MAX_REQUEST_BYTES) throw new Error("Request too large");
  }
  if (!request.body) throw new Error("Expected JSON");

  const reader = request.body.getReader();
  const decoder = new TextDecoder("utf-8", { fatal: true });
  let size = 0;
  let text = "";
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > MAX_REQUEST_BYTES) {
        await reader.cancel();
        throw new Error("Request too large");
      }
      text += decoder.decode(value, { stream: true });
    }
    text += decoder.decode();
  } catch (cause) {
    try { await reader.cancel(); } catch { /* Keep the original parsing or stream error. */ }
    throw cause;
  } finally {
    reader.releaseLock();
  }

  return JSON.parse(text) as unknown;
}

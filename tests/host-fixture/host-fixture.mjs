const replies = new Map();
const replyCounts = new Map();
let iframeReply = false;
const result = document.getElementById("result");
window.cynaReply = reply => {
  replyCounts.set(reply.id, (replyCounts.get(reply.id) || 0) + 1);
  if (reply.id === 503) iframeReply = true;
  else replies.set(reply.id, reply);
};
window.cynaHandshake = session => {
  if (window.testSession) return;
  window.testSession = session;
  const bridge = window.webkit.messageHandlers.cyna;
  bridge.postMessage({ ...session, id: 501, kind: "invoke", command: "unknown.call", args: {}, deadlineMs: 1000 });
  bridge.postMessage({ ...session, id: 502, kind: "invoke", command: "text.score",
    args: { text: "x".repeat(70000), enabled: true, factor: 2 }, deadlineMs: 1000 });
  bridge.postMessage({ ...session, id: 504, kind: "invoke", command: "math.slowDouble",
    args: { value: 7 }, deadlineMs: 1 });
  bridge.postMessage({ ...session, window: "wrong-window", id: 505, kind: "invoke",
    command: "math.double", args: { value: 7 }, deadlineMs: 1000 });
  for (let id = 600; id <= 616; id++)
    bridge.postMessage({ ...session, id, kind: "subscribe", topic: "app.windows" });
  const frame = document.createElement("iframe");
  frame.src = "/frame.html";
  document.body.append(frame);
  setTimeout(() => { window.location.href = "https://example.com/"; }, 300);
  setTimeout(() => {
    const unknown = replies.get(501)?.error?.code === "UNKNOWN_COMMAND";
    const oversized = replies.get(502)?.error?.code === "INVALID_ARGUMENT";
    const local = window.location.protocol === "cyna-app:";
    const timeout = replies.get(504)?.error?.code === "TIMEOUT" && replyCounts.get(504) === 1;
    const isolated = !replies.has(505);
    const bounded = Array.from({ length: 16 }, (_, index) => replies.get(600 + index)?.ok === true).every(Boolean) &&
      replies.get(616)?.error?.code === "LIMIT_EXCEEDED";
    result.textContent = unknown && oversized && timeout && isolated && bounded && !iframeReply && local
      ? "PASS host policy" : `FAIL unknown=${unknown} oversized=${oversized} timeout=${timeout} isolated=${isolated} bounded=${bounded} iframe=${iframeReply} local=${local}`;
  }, 1200);
};
window.webkit.messageHandlers.cyna.postMessage({ kind: "hello" });

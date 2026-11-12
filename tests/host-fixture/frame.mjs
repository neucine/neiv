const session = window.parent.testSession;
window.webkit.messageHandlers.cyna.postMessage({
  ...session,
  id: 503,
  kind: "invoke",
  command: "math.double",
  args: { value: 7 },
  deadlineMs: 1000,
});

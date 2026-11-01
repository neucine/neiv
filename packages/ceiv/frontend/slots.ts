// Generated into apps by Ceiv. Optional native surface placement API.
type SlotBridge = { postMessage(message: Record<string, unknown>): void };

export function attachNativeSlot(element: HTMLElement, slot: string): () => void {
  if (!/^[A-Za-z_][A-Za-z_0-9-]{0,63}$/.test(slot)) throw new Error("Invalid native slot ID");
  const bridge = (window as any).webkit?.messageHandlers?.surface as SlotBridge | undefined;
  if (!bridge) throw new Error("This app has no native surface module");
  let active = true;
  let scheduled = false;
  const send = () => {
    scheduled = false;
    if (!active) return;
    const rect = element.getBoundingClientRect();
    bridge.postMessage({ kind: "slot", slot, x: rect.x, y: rect.y,
      width: element.isConnected ? rect.width : 0,
      height: element.isConnected ? rect.height : 0 });
  };
  const schedule = () => {
    if (active && !scheduled) { scheduled = true; requestAnimationFrame(send); }
  };
  const observer = new ResizeObserver(schedule);
  observer.observe(element);
  window.addEventListener("resize", schedule);
  window.addEventListener("scroll", schedule, true);
  const dispose = () => {
    if (!active) return;
    active = false;
    observer.disconnect();
    window.removeEventListener("resize", schedule);
    window.removeEventListener("scroll", schedule, true);
    window.removeEventListener("pagehide", dispose);
    bridge.postMessage({ kind: "slot", slot, x: 0, y: 0, width: 0, height: 0 });
  };
  window.addEventListener("pagehide", dispose, { once: true });
  schedule();
  return dispose;
}

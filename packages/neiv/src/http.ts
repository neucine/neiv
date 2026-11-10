// Requests stay inside the native host. The page never receives the endpoint or headers.
export type LocalHttpEvent = { streamId: string; kind: 'data' | 'error' | 'closed'; value: unknown };
type Reply = { id: number; status: number; body: unknown; error?: string };
const pending = new Map<number, { resolve(value: unknown): void; reject(error: Error): void }>();
const streams = new Map<string, (event: LocalHttpEvent) => void>();
let nextId = 0;

(window as any).neivHttpReply = (reply: Reply) => {
  const call = pending.get(reply.id);
  if (!call) return;
  pending.delete(reply.id);
  if (reply.error || reply.status < 200 || reply.status >= 300)
    call.reject(new Error(reply.error || (reply.body as { error?: string })?.error || `HTTP ${reply.status}`));
  else call.resolve(reply.body);
};
(window as any).neivHttpEvent = (event: LocalHttpEvent) => streams.get(event.streamId)?.(event);

function send(message: object): void {
  (window as any).webkit.messageHandlers.neivHttp.postMessage(message);
}

export const localHttp = {
  request<T = unknown>(path: string, method: 'GET' | 'POST' = 'GET', body?: object): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      const id = ++nextId;
      pending.set(id, { resolve: value => resolve(value as T), reject });
      try { send({ id, path, method, body: body || {} }); }
      catch (error) { pending.delete(id); reject(error); }
    });
  },
  subscribe(path: string, streamId: string, onEvent: (event: LocalHttpEvent) => void): () => void {
    streams.set(streamId, onEvent);
    try { send({ action: 'startEvents', streamId, path }); }
    catch (error) { streams.delete(streamId); throw error; }
    return () => {
      if (streams.get(streamId) === onEvent) {
        streams.delete(streamId);
        send({ action: 'stopEvents', streamId });
      }
    };
  },
};

window.addEventListener('pagehide', () => {
  for (const call of pending.values()) call.reject(new Error('Page closed'));
  pending.clear();
  streams.clear();
});

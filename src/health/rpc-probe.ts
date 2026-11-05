export interface HealthStatus {
  healthy: boolean;
  rpcLatencyMs: number;
  blockHeight?: number;
  checkedAt: number;
}

export class RpcHealthMonitor {
  constructor(private rpcUrl: string) {}

  public async checkHealth(): Promise<HealthStatus> {
    const start = Date.now();
    try {
      const resp = await fetch(this.rpcUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ jsonrpc: '2.0', method: 'eth_blockNumber', params: [], id: 1 })
      });
      const data = await resp.json();
      const latency = Date.now() - start;
      const blockHeight = data.result ? parseInt(data.result, 16) : undefined;
      return {
        healthy: resp.ok,
        rpcLatencyMs: latency,
        blockHeight,
        checkedAt: Date.now()
      };
    } catch {
      return {
        healthy: false,
        rpcLatencyMs: -1,
        checkedAt: Date.now()
      };
    }
  }
}

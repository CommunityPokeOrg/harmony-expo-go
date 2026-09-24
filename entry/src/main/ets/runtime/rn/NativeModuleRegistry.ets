/**
 * Native module registry — the dispatch seam for RN's bridge calls.
 *
 * In a real RN runtime the JS side reaches native code through
 * BatchedBridge / the interop layer (callFunctionReturnFlushedQueue,
 * callNativeSyncHook, etc.): (moduleName, methodName, argsJSON) -> result.
 * NativeModule models one such module; the registry resolves the name and
 * invokes synchronously, returning a JSON-encoded {ok, result | error}
 * envelope the engine adapter can hand back to JS.
 *
 * ArkTS cannot receive dynamic calls without a statically-typed interface,
 * so modules implement invoke() with a string method name and a JSON arg
 * array — the same shape the bridge protocol already uses.
 */
export interface NativeModule {
  /** The name JS sees, e.g. 'DeviceInfo', 'Timing'. */
  readonly name: string;
  /** Constants merged into the module description sent to JS at init. */
  getConstants(): Record<string, Object>;
  /**
   * Synchronous dispatch. args mirrors the JSON array RN sends.
   * Throw to reject the call — the registry encodes it as {error:...}.
   */
  invoke(method: string, args: Object[]): Object;
}

export class NativeModuleRegistry {
  private modules: Map<string, NativeModule> = new Map();

  register(module: NativeModule): void {
    this.modules.set(module.name, module);
  }

  has(name: string): boolean {
    return this.modules.has(name);
  }

  names(): string[] {
    const out: string[] = [];
    for (const entry of this.modules) {
      out.push(entry[0]);
    }
    return out;
  }

  /**
   * Module table serialized for the engine's global BatchedBridge config
   * (the 'remoteModuleConfig' JS consumes at bridge init).
   */
  remoteModuleConfigJson(): string {
    const config: Record<string, Object> = {};
    for (const entry of this.modules) {
      const m = entry[1];
      const constants = m.getConstants();
      const constKeys = Object.keys(constants);
      const constRecord: Record<string, Object> = {};
      for (const k of constKeys) {
        constRecord[k] = constants[k];
      }
      config[m.name] = constRecord;
    }
    return JSON.stringify(config);
  }

  /**
   * Executes one bridge call. Returns a JSON string:
   *   {"ok":true,"result":<value>}  or  {"ok":false,"error":"<message>"}
   */
  call(moduleName: string, method: string, argsJson: string): string {
    const module = this.modules.get(moduleName);
    if (module === undefined) {
      return JSON.stringify({ ok: false, error: 'unknown module: ' + moduleName });
    }
    let args: Object[] = [];
    try {
      const parsed = JSON.parse(argsJson) as Object;
      if (parsed instanceof Array) {
        args = parsed;
      }
    } catch (e) {
      return JSON.stringify({ ok: false, error: 'bad args json' });
    }
    try {
      const result = module.invoke(method, args);
      return JSON.stringify({ ok: true, result: result });
    } catch (e) {
      const message = e instanceof Error ? e.message : 'native call failed';
      return JSON.stringify({ ok: false, error: message });
    }
  }
}

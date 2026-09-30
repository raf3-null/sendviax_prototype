// Reference the existing HTTPS Date header, without trusting the device wall clock.
// This does not extend protocol TTLs or change authenticated envelope fields.
export class RelayClock {
  private anchor: {epochMs: number; monotonicMs: number} | null = null;
  sync(date: string | null, started: number, received = performance.now()) {
    if (!date) throw Error('Relay ไม่ได้ส่งเวลาสำหรับตรวจอายุรายการ กรุณาลองใหม่');
    const epochMs = Date.parse(date);
    if (!Number.isFinite(epochMs)) throw Error('เวลา Relay ไม่ถูกต้อง');
    this.anchor = {epochMs: epochMs + Math.max(0, received - started) / 2, monotonicMs: received};
  }
  nowSeconds(monotonicMs = performance.now()) {
    if (!this.anchor) throw Error('กรุณาเชื่อมต่อ Relay เพื่อตรวจเวลาก่อน');
    return (this.anchor.epochMs + Math.max(0, monotonicMs - this.anchor.monotonicMs)) / 1000;
  }
}

// src/core/AudioManager.ts
// 使用 Web Audio API 靜態合成音效，無需外部音檔

export class AudioManager {
    private static ctx: AudioContext | null = null;

    private static getCtx(): AudioContext {
        if (!this.ctx) {
            this.ctx = new AudioContext();
        }
        return this.ctx;
    }

    /** UI 按鈕點擊聲（高頻短音） */
    public static playClick(): void {
        try {
            const ctx = this.getCtx();
            const osc = ctx.createOscillator();
            const gain = ctx.createGain();
            osc.type = 'sine';
            osc.frequency.setValueAtTime(800, ctx.currentTime);
            osc.frequency.exponentialRampToValueAtTime(600, ctx.currentTime + 0.06);
            gain.gain.setValueAtTime(0.15, ctx.currentTime);
            gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.08);
            osc.connect(gain).connect(ctx.destination);
            osc.start(ctx.currentTime);
            osc.stop(ctx.currentTime + 0.08);
        } catch {
            // 靜默失敗（不影響遊戲運行）
        }
    }

    /** 單位移動踏步聲 */
    public static playMove(): void {
        try {
            const ctx = this.getCtx();
            const osc = ctx.createOscillator();
            const gain = ctx.createGain();
            osc.type = 'triangle';
            osc.frequency.setValueAtTime(120, ctx.currentTime);
            osc.frequency.exponentialRampToValueAtTime(80, ctx.currentTime + 0.1);
            gain.gain.setValueAtTime(0.2, ctx.currentTime);
            gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.12);
            osc.connect(gain).connect(ctx.destination);
            osc.start(ctx.currentTime);
            osc.stop(ctx.currentTime + 0.12);
        } catch {
            // 靜默失敗
        }
    }

    /** 攻擊命中重擊聲 */
    public static playHit(): void {
        try {
            const ctx = this.getCtx();
            // Noise burst for impact
            const bufferSize = ctx.sampleRate * 0.15;
            const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
            const data = buffer.getChannelData(0);
            for (let i = 0; i < bufferSize; i++) {
                data[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / bufferSize, 3);
            }
            const noise = ctx.createBufferSource();
            noise.buffer = buffer;

            const gain = ctx.createGain();
            gain.gain.setValueAtTime(0.3, ctx.currentTime);
            gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.15);

            // 低頻衝擊
            const osc = ctx.createOscillator();
            const oscGain = ctx.createGain();
            osc.type = 'sine';
            osc.frequency.setValueAtTime(150, ctx.currentTime);
            osc.frequency.exponentialRampToValueAtTime(40, ctx.currentTime + 0.15);
            oscGain.gain.setValueAtTime(0.35, ctx.currentTime);
            oscGain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.15);

            noise.connect(gain).connect(ctx.destination);
            osc.connect(oscGain).connect(ctx.destination);
            noise.start(ctx.currentTime);
            noise.stop(ctx.currentTime + 0.15);
            osc.start(ctx.currentTime);
            osc.stop(ctx.currentTime + 0.15);
        } catch {
            // 靜默失敗
        }
    }

    /** 勝利音效（上升音階） */
    public static playVictory(): void {
        try {
            const ctx = this.getCtx();
            const notes = [523, 659, 784, 1047]; // C5, E5, G5, C6
            notes.forEach((freq, i) => {
                const osc = ctx.createOscillator();
                const gain = ctx.createGain();
                osc.type = 'sine';
                osc.frequency.value = freq;
                const startTime = ctx.currentTime + i * 0.15;
                gain.gain.setValueAtTime(0, startTime);
                gain.gain.linearRampToValueAtTime(0.2, startTime + 0.05);
                gain.gain.exponentialRampToValueAtTime(0.001, startTime + 0.25);
                osc.connect(gain).connect(ctx.destination);
                osc.start(startTime);
                osc.stop(startTime + 0.25);
            });
        } catch {
            // 靜默失敗
        }
    }
}
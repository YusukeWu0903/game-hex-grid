// src/core/JuiceEffects.ts
// 使用 GSAP 實作畫面視覺特效（震動、飄字彈跳）

import gsap from 'gsap';

export class JuiceEffects {
    /** 畫面微幅震動：讓 Canvas 在受傷時產生 0.2 秒的 X/Y 軸隨機震動 */
    public static shakeCanvas(canvas: HTMLCanvasElement): void {
        try {
            gsap.killTweensOf(canvas);
            gsap.fromTo(
                canvas,
                { x: 0, y: 0 },
                {
                    x: () => (Math.random() * 2 - 1) * 8,
                    y: () => (Math.random() * 2 - 1) * 8,
                    duration: 0.05,
                    repeat: 3,
                    yoyo: true,
                    ease: 'power1.out',
                    onComplete: () => {
                        gsap.set(canvas, { x: 0, y: 0 });
                    }
                }
            );
        } catch {
            // 靜默失敗（不影響遊戲運行）
        }
    }

    /** 飄字打擊動畫：放大彈跳 + 漸隱 */
    public static animateDamageText(el: HTMLElement): void {
        try {
            gsap.killTweensOf(el);
            gsap.fromTo(
                el,
                { scale: 0.4, opacity: 1, y: 0 },
                {
                    scale: 1.4,
                    opacity: 0,
                    y: -40,
                    duration: 0.6,
                    ease: 'power2.out'
                }
            );
        } catch {
            // 靜默失敗
        }
    }
}
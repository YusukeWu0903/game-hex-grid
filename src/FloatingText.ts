// src/FloatingText.ts

export class FloatingText {
    public text: string;
    public x: number;
    public y: number;
    public color: string;
    public alpha: number = 1.0;
    private lifeSpan: number = 40; // 動畫持續幀數 (約 0.6 秒)
    public isDead: boolean = false;

    constructor(text: string, x: number, y: number, color: string = '#ff1744') {
        this.text = text;
        this.x = x;
        this.y = y;
        this.color = color;
    }

    public update(): void {
        this.y -= 0.8; // 文字向上飄移
        this.alpha -= 1 / this.lifeSpan; // 漸隱效果

        if (this.alpha <= 0) {
            this.alpha = 0;
            this.isDead = true; // 修正：移除多餘的 : boolean
        }
    }

    public draw(ctx: CanvasRenderingContext2D): void {
        ctx.save();
        ctx.globalAlpha = this.alpha;
        ctx.fillStyle = this.color;
        ctx.font = 'bold 22px Arial';
        ctx.textAlign = 'center';
        ctx.strokeStyle = '#ffffff';
        ctx.lineWidth = 3; // 加厚白色描邊，讓數字更清晰
        ctx.strokeText(this.text, this.x, this.y);
        ctx.fillText(this.text, this.x, this.y);
        ctx.restore();
    }
}
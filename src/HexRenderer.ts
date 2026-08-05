import { HexGrid } from './HexGrid';
import { HexNode } from './HexNode';
import { Unit } from './entities/Unit';
import { FloatingText } from './FloatingText'; // 同一層目錄直接引用

export class HexRenderer {
    private canvas: HTMLCanvasElement;
    private ctx: CanvasRenderingContext2D;
    private hexSize: number;
    // 讓地圖畫在畫面正中央的偏移量
    private offsetX: number = 0;
    private offsetY: number = 0;

    constructor(canvasId: string, hexSize: number = 40) {
        this.canvas = document.getElementById(canvasId) as HTMLCanvasElement;
        this.ctx = this.canvas.getContext('2d')!;
        this.hexSize = hexSize;

        // 初始化螢幕尺寸並綁定視窗縮放事件
        this.resizeCanvas();
        window.addEventListener('resize', () => this.resizeCanvas());
    }

    /**
     * 動態調整 Canvas 畫布大小為全螢幕，並重新計算中心點偏移量
     */
    public resizeCanvas(): void {
        this.canvas.width = window.innerWidth;
        this.canvas.height = window.innerHeight;

        // 每次縮放都重新將 (0,0,0) 設定在當前畫布的正中央
        this.offsetX = this.canvas.width / 2;
        this.offsetY = this.canvas.height / 2;
    }

    // 核心數學：把 (x,y,z) 轉成畫布上的 (pixelX, pixelY)
    private getPixelCoords(node: HexNode): { px: number, py: number } {
        const px = this.hexSize * Math.sqrt(3) * (node.x + node.z / 2);
        const py = this.hexSize * (3 / 2) * node.z;
        
        return {
            px: px + this.offsetX,
            py: py + this.offsetY
        };
    }

    // 將單一 characterNode 改為傳入 units 單位陣列
    public render(grid: HexGrid, path: HexNode[] = [], reachableNodes: HexNode[] = [], units: Unit[] = [], attackableNodes: HexNode[] = []): void {
        this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
        
        grid.getNodes().forEach(node => {
            const isPath = path.some(p => p.equals(node));
            const isReachable = reachableNodes.some(r => r.equals(node));
            const isAttackable = attackableNodes.some(a => a.equals(node)); // 檢查是否在攻擊範圍內
            
            this.drawHex(node, isPath, isReachable, isAttackable);
        });

        // 畫出場上所有單位 (我方與敵方)
        units.forEach(unit => {
            this.drawUnit(unit);
        });

        // ✏️ 新增這行：繪製與更新浮動文字
        this.renderFloatingTexts();
    }

    // 擴充 drawHex，加入 isAttackable 參數
    private drawHex(node: HexNode, isPath: boolean = false, isReachable: boolean = false, isAttackable: boolean = false): void {
        const { px, py } = this.getPixelCoords(node);

        this.ctx.beginPath();
        for (let i = 0; i < 6; i++) {
            const angle_rad = Math.PI / 180 * (60 * i - 30);
            const vertexX = px + this.hexSize * Math.cos(angle_rad);
            const vertexY = py + this.hexSize * Math.sin(angle_rad);
            if (i === 0) this.ctx.moveTo(vertexX, vertexY);
            else this.ctx.lineTo(vertexX, vertexY);
        }
        this.ctx.closePath();

        // 著色優先順序：不可通行/山脈(灰) > 路徑(黃) > 攻擊範圍(紅) > 移動範圍(淺綠) > 森林(深綠) > 平地(淺藍)
        if (!node.isWalkable || node.terrain === 'MOUNTAIN') {
            this.ctx.fillStyle = '#757575'; // 山脈 (灰色)
        } else if (isPath) {
            this.ctx.fillStyle = '#ffe082'; // 路徑
        } else if (isAttackable) {
            this.ctx.fillStyle = '#ffcdd2'; // 攻擊範圍
        } else if (isReachable) {
            this.ctx.fillStyle = '#c8e6c9'; // 可移動範圍
        } else if (node.terrain === 'FOREST') {
            this.ctx.fillStyle = '#2e7d32'; // 森林 (顯眼的深綠色)
        } else {
            this.ctx.fillStyle = '#e0f7fa'; // 平地 (淺藍)
        }

        this.ctx.fill();
        this.ctx.strokeStyle = '#006064';
        this.ctx.lineWidth = 1;
        this.ctx.stroke();

        // 1. 繪製座標 (x,y,z)
        this.ctx.fillStyle = '#000000';
        this.ctx.font = '12px Arial';
        this.ctx.textAlign = 'center';
        this.ctx.textBaseline = 'middle';
        this.ctx.fillText(`${node.x},${node.y},${node.z}`, px, py - 6);

        // 2. 新增：標示地形名稱與移動消耗 Cost
        this.ctx.font = '10px Arial';
        if (node.terrain === 'FOREST') {
            this.ctx.fillStyle = '#ffffff'; // 森林深底配白字
            this.ctx.fillText('森林 (Cost 2)', px, py + 8);
        } else if (node.terrain === 'MOUNTAIN' || !node.isWalkable) {
            this.ctx.fillStyle = '#ffffff';
            this.ctx.fillText('山脈 (不可通行)', px, py + 8);
        } else {
            this.ctx.fillStyle = '#555555';
            this.ctx.fillText('Cost 1', px, py + 8);
        }
    }

    // 新增：繪製場上單位棋子 (包含名稱標籤與 HP/MP)
    private drawUnit(unit: Unit): void {
        const { px, py } = this.getPixelCoords(unit.node);
        
        this.ctx.beginPath();
        this.ctx.arc(px, py, this.hexSize * 0.55, 0, Math.PI * 2);
        
        // 顏色樣式：已行動變灰、我方藍色、敵方紅色
        if (unit.hasActed) {
            this.ctx.fillStyle = '#757575'; // 已行動 (灰色)
        } else if (unit.faction === 'PLAYER') {
            this.ctx.fillStyle = '#1e88e5'; // 我方 (藍色)
        } else if (unit.faction === 'NEUTRAL') {
            this.ctx.fillStyle = '#fbc02d'; // 第三方 / 中立 (黃色)
        } else {
            this.ctx.fillStyle = '#e53935'; // 敵方 (紅色)
        }

        this.ctx.fill();
        this.ctx.strokeStyle = '#ffffff';
        this.ctx.lineWidth = 3;
        this.ctx.stroke();

        // 畫上單位名稱標籤 (如 P1, P2, E1)
        this.ctx.fillStyle = '#ffffff';
        this.ctx.font = 'bold 16px Arial';
        this.ctx.textAlign = 'center';
        this.ctx.textBaseline = 'middle';
        this.ctx.fillText(unit.id, px, py - 4);

        // 顯示當前 HP
        this.ctx.font = '13px Arial';
        this.ctx.fillText(`${unit.hp}HP`, px, py + 10);

        // 1. 繪製血條 (紅/綠條)
        const barWidth = 50;
        const barHeight = 6;
        const barX = px - barWidth / 2; // 直接使用上方已經解析好的 px
        const barY = py + 22;           // 直接使用上方已經解析好的 py

        this.ctx.fillStyle = 'rgba(0, 0, 0, 0.6)';
        this.ctx.fillRect(barX, barY, barWidth, barHeight);
        this.ctx.fillStyle = '#4caf50';
        this.ctx.fillRect(barX, barY, (unit.hp / unit.maxHp) * barWidth, barHeight);

        // 2. 繪製藍條 (MP 藍條)
        const mpBarY = barY + 7;
        this.ctx.fillStyle = 'rgba(0, 0, 0, 0.6)';
        this.ctx.fillRect(barX, mpBarY, barWidth, 5);
        this.ctx.fillStyle = '#2196f3'; // 藍色
        this.ctx.fillRect(barX, mpBarY, (unit.mp / unit.maxMp) * barWidth, 5);
    }

    /**
     * 將螢幕的像素座標轉換回六角格的立方體座標
     */
    public pixelToHex(mouseX: number, mouseY: number): { x: number, y: number, z: number } {
        // 先扣除畫布偏移量，回到以地圖中心為原點的相對座標
        const px = mouseX - this.offsetX;
        const py = mouseY - this.offsetY;

        // 尖頂朝上六角格的反向轉換矩陣公式
        const q = (Math.sqrt(3) / 3 * px - 1 / 3 * py) / this.hexSize;
        const r = (2 / 3 * py) / this.hexSize;
        const s = -q - r;

        // 透過 cubeRound 修正小數點誤差
        return this.cubeRound(q, s, r);
    }

    /**
     * 六角格專用的四捨五入演算法
     */
    private cubeRound(fracX: number, fracY: number, fracZ: number): { x: number, y: number, z: number } {
        let rx = Math.round(fracX);
        let ry = Math.round(fracY);
        let rz = Math.round(fracZ);

        const xDiff = Math.abs(rx - fracX);
        const yDiff = Math.abs(ry - fracY);
        const zDiff = Math.abs(rz - fracZ);

        if (xDiff > yDiff && xDiff > zDiff) {
            rx = -ry - rz;
        } else if (yDiff > zDiff) {
            ry = -rx - rz;
        } else {
            rz = -rx - ry;
        }

        return { x: rx, y: ry, z: rz };
    }
    /**
     * 繪製左上角遊戲狀態 HUD (回合數與目前階段)
     */
    public drawHUD(turnCount: number, stateText: string): void {
        this.ctx.fillStyle = 'rgba(0, 0, 0, 0.6)';
        this.ctx.fillRect(10, 10, 180, 50);

        this.ctx.fillStyle = '#ffffff';
        this.ctx.font = 'bold 14px Arial';
        this.ctx.textAlign = 'left';
        this.ctx.textBaseline = 'middle';
        this.ctx.fillText(`回合: ${turnCount}`, 20, 25);
        this.ctx.fillText(`階段: ${stateText}`, 20, 45);
    }

    /**
     * 繪製 GAME OVER (VICTORY / DEFEAT) 全螢幕橫幅
     */
    public drawGameOver(isVictory: boolean): void {
        // 半透明黑底
        this.ctx.fillStyle = 'rgba(0, 0, 0, 0.7)';
        this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);

        // 文字樣式
        this.ctx.font = 'bold 36px Arial';
        this.ctx.textAlign = 'center';
        this.ctx.textBaseline = 'middle';

        if (isVictory) {
            this.ctx.fillStyle = '#4caf50'; // 綠色 Victory
            this.ctx.fillText('🎉 VICTORY 🎉', this.canvas.width / 2, this.canvas.height / 2);
        } else {
            this.ctx.fillStyle = '#f44336'; // 紅色 Defeat
            this.ctx.fillText('💀 DEFEAT 💀', this.canvas.width / 2, this.canvas.height / 2);
        }
    }

    private floatingTexts: FloatingText[] = [];

    // 新增：觸發飄字效果
    public addFloatingText(node: HexNode, text: string, color: string = '#ff1744'): void {
        const { px, py } = this.getPixelCoords(node);
        this.floatingTexts.push(new FloatingText(text, px, py - 20, color));
    }

    // 繪製與更新飄字
    private renderFloatingTexts(): void {
        for (let i = this.floatingTexts.length - 1; i >= 0; i--) {
            const ft = this.floatingTexts[i];
            ft.update();
            ft.draw(this.ctx);
            if (ft.isDead) {
                this.floatingTexts.splice(i, 1);
            }
        }
    }
}
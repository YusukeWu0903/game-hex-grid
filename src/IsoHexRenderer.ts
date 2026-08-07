// src/IsoHexRenderer.ts
import { HexGrid } from './HexGrid';
import { HexNode } from './HexNode';
import { Unit } from './entities/Unit';
import { FloatingText } from './FloatingText';

export class IsoHexRenderer {
    private canvas: HTMLCanvasElement;
    private ctx: CanvasRenderingContext2D;
    private hexSize: number;
    private offsetX: number = 0;
    private offsetY: number = 0;
    private floatingTexts: FloatingText[] = [];

    constructor(canvasId: string, hexSize: number = 55) {
        this.canvas = document.getElementById(canvasId) as HTMLCanvasElement;
        this.ctx = this.canvas.getContext('2d')!;
        this.hexSize = hexSize;

        this.resizeCanvas();
        window.addEventListener('resize', () => this.resizeCanvas());
    }

    public resizeCanvas(): void {
        this.canvas.width = window.innerWidth;
        this.canvas.height = window.innerHeight;
        const panelWidthOffset = 110; // 面板寬度的一半，讓地圖向右微調避免被左側面板遮擋
        this.offsetX = (this.canvas.width / 2) + panelWidthOffset;
        this.offsetY = this.canvas.height / 2;
    }

    public getPixelCoords(node: HexNode): { px: number, py: number } {
        const px = this.hexSize * Math.sqrt(3) * (node.x + node.z / 2);
        const py = this.hexSize * (3 / 2) * node.z;
        return {
            px: px + this.offsetX,
            py: py + this.offsetY
        };
    }

    public render(grid: HexGrid, path: HexNode[] = [], reachableNodes: HexNode[] = [], units: Unit[] = [], attackableNodes: HexNode[] = []): void {
        // 1. 清空畫布並填滿深色背景
        this.ctx.fillStyle = '#080b10';
        this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);

        // 2. 排序格子 (Z 軸小者先畫，前方晶體才不會蓋住後方的頂面)
        const sortedNodes = [...grid.getNodes()].sort((a, b) => a.z - b.z || a.x - b.x);

        sortedNodes.forEach(node => {
            const isPath = path.some(p => p.equals(node));
            const isReachable = reachableNodes.some(r => r.equals(node));
            const isAttackable = attackableNodes.some(a => a.equals(node));

            this.drawIsoHex(node, isPath, isReachable, isAttackable);
        });

        // 3. 繪製單位
        units.forEach(unit => {
            this.drawUnit(unit);
        });

        // 4. 繪製傷害飄字
        this.renderFloatingTexts();
    }

    private drawIsoHex(node: HexNode, isPath: boolean, isReachable: boolean, isAttackable: boolean): void {
        const { px, py } = this.getPixelCoords(node);

        // 依據地形設定不同柱體厚度 h
        let h = 8; // PLAIN 平地
        let sideColor = '#0d131f';
        let topColor = '#1e293b';
        let topStroke = '#334155';
        let labelText = 'Cost 1';
        let labelColor = '#64748b';

        if (node.terrain === 'FOREST') {
            h = 12;
            sideColor = '#0a2e12';
            topColor = '#1b5e20';
            topStroke = '#2e7d32';
            labelText = '森林 (Cost 2)';
            labelColor = '#a5d6a7';
        } else if (node.terrain === 'SWAMP') {
            h = 12;
            sideColor = '#1f2612';
            topColor = '#3f4f24';
            topStroke = '#556b2f';
            labelText = '沼澤 (Cost 2)';
            labelColor = '#cddc39';
        } else if (node.terrain === 'HILLS') {
            h = 20; // 凸起
            sideColor = '#4a3525';
            topColor = '#8d6e63';
            topStroke = '#a1887f';
            labelText = '丘陵 (Cost 2)';
            labelColor = '#d7ccc8';
        } else if (node.terrain === 'WATER') {
            h = 2; // 凹陷
            sideColor = '#023354';
            topColor = '#0284c7';
            topStroke = '#38bdf8';
            labelText = '水域 (需船隻)';
            labelColor = '#bae6fd';
        } else if (node.terrain === 'MOUNTAIN' || !node.isWalkable) {
            h = 32;
            sideColor = '#1c252b';
            topColor = '#37474f';
            topStroke = '#546e7a';
            labelText = '山脈 (不可通行)';
            labelColor = '#b0bec5';
        }

        // 計算頂面 6 個頂點座標
        const topVertices: { x: number, y: number }[] = [];
        for (let i = 0; i < 6; i++) {
            const angle = Math.PI / 180 * (60 * i - 30);
            topVertices.push({
                x: px + this.hexSize * Math.cos(angle),
                y: py + this.hexSize * Math.sin(angle)
            });
        }

        // --- A. 繪製柱體側面 ---
        this.ctx.beginPath();
        this.ctx.moveTo(topVertices[1].x, topVertices[1].y);
        this.ctx.lineTo(topVertices[2].x, topVertices[2].y);
        this.ctx.lineTo(topVertices[3].x, topVertices[3].y);
        this.ctx.lineTo(topVertices[4].x, topVertices[4].y);
        this.ctx.lineTo(topVertices[4].x, topVertices[4].y + h);
        this.ctx.lineTo(topVertices[3].x, topVertices[3].y + h);
        this.ctx.lineTo(topVertices[2].x, topVertices[2].y + h);
        this.ctx.lineTo(topVertices[1].x, topVertices[1].y + h);
        this.ctx.closePath();

        this.ctx.fillStyle = sideColor;
        this.ctx.fill();
        this.ctx.strokeStyle = '#05070a';
        this.ctx.lineWidth = 1;
        this.ctx.stroke();

        // --- B. 繪製正六邊形頂面 (Top Face) ---
        this.ctx.beginPath();
        this.ctx.moveTo(topVertices[0].x, topVertices[0].y);
        for (let i = 1; i < 6; i++) {
            this.ctx.lineTo(topVertices[i].x, topVertices[i].y);
        }
        this.ctx.closePath();

        this.ctx.shadowBlur = 0;

        // 頂面著色與 Neon 霓虹外發光
        if (isPath) {
            this.ctx.fillStyle = 'rgba(255, 215, 0, 0.35)';
            this.ctx.strokeStyle = '#ffd700';
            this.ctx.lineWidth = 2.5;
            this.ctx.shadowColor = '#ffd700';
            this.ctx.shadowBlur = 12;
        } else if (isAttackable) {
            this.ctx.fillStyle = 'rgba(255, 52, 52, 0.3)';
            this.ctx.strokeStyle = '#ff3333';
            this.ctx.lineWidth = 2.5;
            this.ctx.shadowColor = '#ff3333';
            this.ctx.shadowBlur = 12;
        } else if (isReachable) {
            this.ctx.fillStyle = 'rgba(0, 230, 118, 0.25)';
            this.ctx.strokeStyle = '#00e676';
            this.ctx.lineWidth = 2;
            this.ctx.shadowColor = '#00e676';
            this.ctx.shadowBlur = 10;
        } else {
            this.ctx.fillStyle = topColor;
            this.ctx.strokeStyle = topStroke;
            this.ctx.lineWidth = 1.5;
        }

        this.ctx.fill();
        this.ctx.stroke();
        this.ctx.shadowBlur = 0;

        // --- C. 繪製文字標示 ---
        this.ctx.fillStyle = '#94a3b8';
        this.ctx.font = '11px Consolas, monospace';
        this.ctx.textAlign = 'center';
        this.ctx.textBaseline = 'middle';
        this.ctx.fillText(`${node.x},${node.y},${node.z}`, px, py - 5);

        this.ctx.font = '10px Consolas, monospace';
        this.ctx.fillStyle = labelColor;
        this.ctx.fillText(labelText, px, py + 8);

        // 繪製佈署點標記 (P / E)
        if (node.spawnPoint) {
            this.ctx.font = 'bold 11px Consolas, monospace';
            if (node.spawnPoint === 'PLAYER') {
                this.ctx.fillStyle = '#38bdf8';
                this.ctx.fillText('🚩 P 佈署', px, py + 22);
            } else if (node.spawnPoint === 'ENEMY') {
                this.ctx.fillStyle = '#f87171';
                this.ctx.fillText('💀 E 佈署', px, py + 22);
            }
        }
    }

    private drawUnit(unit: Unit): void {
            // 當 unit 有視覺偏移時 (GSAP 動畫)，使用視覺座標而非 node 座標
            const { px, py } = (unit.visualX !== undefined && unit.visualY !== undefined)
                ? { px: unit.visualX, py: unit.visualY }
                : this.getPixelCoords(unit.node);

        // 1. 底座陰影
        this.ctx.beginPath();
        this.ctx.ellipse(px, py + 14, this.hexSize * 0.42, this.hexSize * 0.2, 0, 0, Math.PI * 2);
        this.ctx.fillStyle = 'rgba(0, 0, 0, 0.6)';
        this.ctx.fill();

        // 2. 棋子外框
        const radius = this.hexSize * 0.45;
        this.ctx.beginPath();
        this.ctx.arc(px, py - 4, radius, 0, Math.PI * 2);

        let primaryColor = '#0284c7'; // 我方
        let borderColor = '#38bdf8';

        if (unit.hasActed) {
            primaryColor = '#334155';
            borderColor = '#64748b';
        } else if (unit.faction === 'ENEMY') {
            primaryColor = '#dc2626'; // 敵方
            borderColor = '#f87171';
        } else if (unit.faction === 'NEUTRAL') {
            primaryColor = '#d97706'; // 中立
            borderColor = '#fbbf24';
        }

        this.ctx.fillStyle = primaryColor;
        this.ctx.fill();
        this.ctx.strokeStyle = borderColor;
        this.ctx.lineWidth = 3;
        this.ctx.stroke();

        this.ctx.strokeStyle = '#ffffff';
        this.ctx.lineWidth = 1;
        this.ctx.stroke();

        // 3. 職業圖示
        this.ctx.strokeStyle = '#ffffff';
        this.ctx.fillStyle = '#ffffff';
        this.ctx.lineCap = 'round';
        this.ctx.lineJoin = 'round';

        const iconY = py - 7;

        if (unit.job.name === '劍士') {
            this.ctx.lineWidth = 2.5;
            this.ctx.beginPath();
            this.ctx.moveTo(px - 8, iconY - 8); this.ctx.lineTo(px + 8, iconY + 8);
            this.ctx.moveTo(px + 8, iconY - 8); this.ctx.lineTo(px - 8, iconY + 8);
            this.ctx.stroke();

            this.ctx.beginPath();
            this.ctx.arc(px - 4, iconY - 4, 1.5, 0, Math.PI * 2);
            this.ctx.arc(px + 4, iconY - 4, 1.5, 0, Math.PI * 2);
            this.ctx.fill();
        } else if (unit.job.name === '弓箭手') {
            this.ctx.lineWidth = 2.5;
            this.ctx.beginPath();
            this.ctx.arc(px + 3, iconY, 8, Math.PI * 0.6, Math.PI * 1.4, false);
            this.ctx.stroke();

            this.ctx.lineWidth = 1.5;
            this.ctx.beginPath();
            this.ctx.moveTo(px + 1, iconY - 7.5);
            this.ctx.lineTo(px + 1, iconY + 7.5);
            this.ctx.moveTo(px - 6, iconY);
            this.ctx.lineTo(px + 8, iconY);
            this.ctx.lineTo(px + 5, iconY - 3);
            this.ctx.moveTo(px + 8, iconY);
            this.ctx.lineTo(px + 5, iconY + 3);
            this.ctx.stroke();
        }

        // 4. 單位名稱標籤
        const tagY = py + 11;
        this.ctx.fillStyle = 'rgba(0, 0, 0, 0.7)';
        this.ctx.fillRect(px - 14, tagY - 7, 28, 13);

        this.ctx.fillStyle = '#ffffff';
        this.ctx.font = 'bold 11px Consolas, monospace';
        this.ctx.textAlign = 'center';
        this.ctx.textBaseline = 'middle';
        this.ctx.fillText(unit.id, px, tagY);

        // 5. 血條 / 藍條
        const barW = 42;
        const barX = px - barW / 2;
        const barY = py + 22;

        this.ctx.fillStyle = '#0f172a';
        this.ctx.fillRect(barX - 1, barY - 1, barW + 2, 6);
        this.ctx.fillStyle = '#15803d';
        this.ctx.fillRect(barX, barY, barW, 4);
        this.ctx.fillStyle = '#22c55e';
        this.ctx.fillRect(barX, barY, (unit.hp / unit.maxHp) * barW, 4);

        const mpBarY = barY + 5;
        this.ctx.fillStyle = '#0f172a';
        this.ctx.fillRect(barX - 1, mpBarY, barW + 2, 5);
        this.ctx.fillStyle = '#0369a1';
        this.ctx.fillRect(barX, mpBarY + 1, barW, 3);
        this.ctx.fillStyle = '#38bdf8';
        this.ctx.fillRect(barX, mpBarY + 1, (unit.mp / unit.maxMp) * barW, 3);
    }

    public pixelToHex(mouseX: number, mouseY: number): { x: number, y: number, z: number } {
        const px = mouseX - this.offsetX;
        const py = mouseY - this.offsetY;

        const q = (Math.sqrt(3) / 3 * px - 1 / 3 * py) / this.hexSize;
        const r = (2 / 3 * py) / this.hexSize;
        const s = -q - r;

        return this.cubeRound(q, s, r);
    }

    private cubeRound(fracX: number, fracY: number, fracZ: number): { x: number, y: number, z: number } {
        let rx = Math.round(fracX);
        let ry = Math.round(fracY);
        let rz = Math.round(fracZ);

        const xDiff = Math.abs(rx - fracX);
        const yDiff = Math.abs(ry - fracY);
        const zDiff = Math.abs(rz - fracZ);

        if (xDiff > yDiff && xDiff > zDiff) rx = -ry - rz;
        else if (yDiff > zDiff) ry = -rx - rz;
        else rz = -rx - ry;

        return { x: rx, y: ry, z: rz };
    }

    public drawHUD(turnCount: number, stateText: string): void {
        this.ctx.fillStyle = 'rgba(15, 23, 42, 0.75)';
        this.ctx.strokeStyle = '#334155';
        this.ctx.lineWidth = 1;
        this.ctx.fillRect(15, 15, 180, 52);
        this.ctx.strokeRect(15, 15, 180, 52);

        this.ctx.fillStyle = '#f8fafc';
        this.ctx.font = 'bold 13px Consolas, monospace';
        this.ctx.textAlign = 'left';
        this.ctx.textBaseline = 'middle';
        this.ctx.fillText(`回合: ${turnCount}`, 25, 32);
        this.ctx.fillText(`階段: ${stateText}`, 25, 52);
    }

    public drawGameOver(isVictory: boolean): void {
        this.ctx.fillStyle = 'rgba(8, 11, 16, 0.85)';
        this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);

        this.ctx.font = 'bold 38px Consolas, monospace';
        this.ctx.textAlign = 'center';
        this.ctx.textBaseline = 'middle';

        if (isVictory) {
            this.ctx.fillStyle = '#4ade80';
            this.ctx.fillText('🎉 VICTORY 🎉', this.canvas.width / 2, this.canvas.height / 2);
        } else {
            this.ctx.fillStyle = '#f87171';
            this.ctx.fillText('💀 DEFEAT 💀', this.canvas.width / 2, this.canvas.height / 2);
        }
    }

    public addFloatingText(node: HexNode, text: string, color: string = '#ff1744'): void {
        const { px, py } = this.getPixelCoords(node);
        this.floatingTexts.push(new FloatingText(text, px, py - 20, color));
    }

    private renderFloatingTexts(): void {
        for (let i = this.floatingTexts.length - 1; i >= 0; i--) {
            const ft = this.floatingTexts[i];
            ft.update();
            ft.draw(this.ctx);
            if (ft.isDead) this.floatingTexts.splice(i, 1);
        }
    }
}

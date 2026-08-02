import { HexNode } from './HexNode';

export class HexGrid {
    // 使用 Map 來儲存所有的格子，Key 為座標字串，Value 為 HexNode
    private nodes: Map<string, HexNode> = new Map();

    // 六個方向的座標偏移量 (對應: 右上, 右, 右下, 左下, 左, 左上)
    private static readonly DIRECTIONS = [
        { x: 1, y: -1, z: 0 }, { x: 1, y: 0, z: -1 }, { x: 0, y: 1, z: -1 },
        { x: -1, y: 1, z: 0 }, { x: -1, y: 0, z: 1 }, { x: 0, y: -1, z: 1 }
    ];

    // 產生一個字串 Key，例如 "(1,-1,0)" -> "1,-1,0"
    private getKey(x: number, y: number, z: number): string {
        return `${x},${y},${z}`;
    }

    // 加入一個格子到地圖中
    public addNode(node: HexNode): void {
        this.nodes.set(this.getKey(node.x, node.y, node.z), node);
    }

    // 取得指定座標的格子，如果超出邊界則回傳 undefined
    public getNode(x: number, y: number, z: number): HexNode | undefined {
        return this.nodes.get(this.getKey(x, y, z));
    }

    /**
     * 功能 1：生成正六邊形狀的地圖
     * @param radius 地圖的半徑 (從中心往外算幾個格子)
     */
    public generateHexagonMap(radius: number): void {
        this.nodes.clear();
        
        // 1. 先用迴圈建立所有 HexNode 格子
        for (let x = -radius; x <= radius; x++) {
            // 計算 y 的合法範圍，確保 x+y+z=0 成立且形狀為六邊形
            const startY = Math.max(-radius, -x - radius);
            const endY = Math.min(radius, -x + radius);
            
            for (let y = startY; y <= endY; y++) {
                const z = -x - y;
                this.addNode(new HexNode(x, y, z));
            }
        }

        // 2. 格子建立完畢後設定地形
        this.getNodes().forEach(node => {
            // 把森林設在玩家 P1/P2 正旁邊 (1,0,-1) 和 (-1,0,1)
            if ((node.x === 1 && node.y === 0) || (node.x === -1 && node.y === 0)) {
                node.terrain = 'FOREST';
            } else if (node.x === 0 && node.y === 2) {
                node.terrain = 'MOUNTAIN';
                node.isWalkable = false; // 山脈不可通行
            }
        });
    }

    /**
     * 功能 2：取得某個格子的周圍相鄰格子 (排除不存在的格子)
     */
    public getNeighbors(node: HexNode): HexNode[] {
        const neighbors: HexNode[] = [];
        for (const dir of HexGrid.DIRECTIONS) {
            const neighborNode = this.getNode(node.x + dir.x, node.y + dir.y, node.z + dir.z);
            if (neighborNode) {
                neighbors.push(neighborNode);
            }
        }
        return neighbors;
    }

    /**
     * 功能 3：計算兩格之間的絕對移動距離 (不需要管障礙物)
     */
    public getDistance(a: HexNode, b: HexNode): number {
        return (Math.abs(a.x - b.x) + Math.abs(a.y - b.y) + Math.abs(a.z - b.z)) / 2;
    }

    public getNodes(): HexNode[] { return Array.from(this.nodes.values()); }
}
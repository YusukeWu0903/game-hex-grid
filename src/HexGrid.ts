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
     * 功能 1：生成正六邊形狀的地圖 (預設全為乾淨的平地 PLAIN)
     * @param radius 地圖的半徑 (從中心往外算幾個格子)
     */
    public generateHexagonMap(radius: number): void {
        this.nodes.clear();
        
        // 建立所有 HexNode 格子 (預設 terrain = 'PLAIN', isWalkable = true)
        for (let x = -radius; x <= radius; x++) {
            const startY = Math.max(-radius, -x - radius);
            const endY = Math.min(radius, -x + radius);
            
            for (let y = startY; y <= endY; y++) {
                const z = -x - y;
                const node = new HexNode(x, y, z);
                node.terrain = 'PLAIN';
                node.isWalkable = true;
                this.addNode(node);
            }
        }
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

export type TerrainType = 'PLAIN' | 'FOREST' | 'MOUNTAIN' | 'SWAMP' | 'WATER' | 'HILLS';
export type SpawnPointType = 'PLAYER' | 'ENEMY' | 'NEUTRAL' | null;

export class HexNode {
    // 1. 立方體座標
    public x: number;
    public y: number;
    public z: number;

    // 2. 節點屬性
    public isWalkable: boolean;
    public cost: number;
    public terrain: TerrainType = 'PLAIN'; // 預設為平地
    public spawnPoint: SpawnPointType = null; // 佈署點標記

    constructor(x: number, y: number, z: number, isWalkable: boolean = true, cost: number = 1) {
        // 【核心防呆】確保傳入的座標符合立方體座標系統的數學規則
        if (Math.round(x + y + z) !== 0) {
            throw new Error(`無效的六角格座標：(${x}, ${y}, ${z}) 的總和必須為 0`);
        }
        
        this.x = x;
        this.y = y;
        this.z = z;
        
        this.isWalkable = isWalkable;
        this.cost = cost;
    }

    // 比較兩個格子是否為同一格
    public equals(other: HexNode): boolean {
        return this.x === other.x && this.y === other.y && this.z === other.z;
    }

    // 將座標格式化為字串
    public toString(): string {
        return `Hex(${this.x}, ${this.y}, ${this.z})`;
    }
}

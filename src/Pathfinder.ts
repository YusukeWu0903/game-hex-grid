// src/Pathfinder.ts
import { HexGrid } from './HexGrid';
import { HexNode } from './HexNode';

export class Pathfinder {
    /**
     * 取得地形移動消耗
     */
    public static getTerrainCost(node: HexNode): number {
        if (!node.isWalkable || node.terrain === 'MOUNTAIN') return 999; // 山脈/障礙無法通行
        if (node.terrain === 'FOREST') return 2; // 森林消耗 2 點移動力
        return 1; // 平地消耗 1 點移動力
    }

    /**
     * 尋找兩點間的最短路徑 (A* 演算法)
     */
    public static findPath(grid: HexGrid, startNode: HexNode, targetNode: HexNode, maxSteps: number = Infinity): HexNode[] {
        if (!targetNode.isWalkable || targetNode.terrain === 'MOUNTAIN') return [];
        if (startNode.equals(targetNode)) return [];

        const openSet: HexNode[] = [startNode];
        const cameFrom: Map<string, HexNode> = new Map();

        const gScore: Map<string, number> = new Map();
        gScore.set(startNode.toString(), 0);

        const fScore: Map<string, number> = new Map();
        fScore.set(startNode.toString(), grid.getDistance(startNode, targetNode));

        while (openSet.length > 0) {
            openSet.sort((a, b) => {
                const fA = fScore.get(a.toString()) ?? Infinity;
                const fB = fScore.get(b.toString()) ?? Infinity;
                return fA - fB;
            });

            const current = openSet.shift()!;

            if (current.equals(targetNode)) {
                const path = this.reconstructPath(cameFrom, current);
                const totalCost = gScore.get(current.toString()) ?? Infinity;
                
                // 如果總移動消耗超過了最大移動力，無法抵達
                if (totalCost > maxSteps) return [];
                return path;
            }

            for (const neighbor of grid.getNeighbors(current)) {
                const stepCost = this.getTerrainCost(neighbor);
                if (stepCost >= 999) continue; // 不可通行

                const tentativeGScore = (gScore.get(current.toString()) ?? Infinity) + stepCost;
                if (tentativeGScore > maxSteps) continue;

                const neighborKey = neighbor.toString();

                if (tentativeGScore < (gScore.get(neighborKey) ?? Infinity)) {
                    cameFrom.set(neighborKey, current);
                    gScore.set(neighborKey, tentativeGScore);
                    fScore.set(neighborKey, tentativeGScore + grid.getDistance(neighbor, targetNode));

                    if (!openSet.some(n => n.equals(neighbor))) {
                        openSet.push(neighbor);
                    }
                }
            }
        }

        return [];
    }

    private static reconstructPath(cameFrom: Map<string, HexNode>, current: HexNode): HexNode[] {
        const path: HexNode[] = [current];
        let currKey = current.toString();
        
        while (cameFrom.has(currKey)) {
            current = cameFrom.get(currKey)!;
            currKey = current.toString();
            path.unshift(current);
        }
        
        path.shift();
        return path;
    }

    /**
     * 找出移動力內可到達的所有格子 (Dijkstra 演算法)
     */
    public static getReachableNodes(grid: HexGrid, startNode: HexNode, maxSteps: number): HexNode[] {
        const reachable: HexNode[] = [];
        const costSoFar: Map<string, number> = new Map();
        const queue: HexNode[] = [startNode];

        const key = (n: HexNode) => n.toString();
        costSoFar.set(key(startNode), 0);

        while (queue.length > 0) {
            // 每次取移動消耗最小的節點
            queue.sort((a, b) => (costSoFar.get(key(a)) ?? Infinity) - (costSoFar.get(key(b)) ?? Infinity));
            const current = queue.shift()!;
            const currentCost = costSoFar.get(key(current))!;

            grid.getNeighbors(current).forEach(neighbor => {
                const stepCost = this.getTerrainCost(neighbor);
                if (stepCost >= 999) return;

                const newCost = currentCost + stepCost;

                if (newCost <= maxSteps) {
                    const neighborKey = key(neighbor);
                    if (!costSoFar.has(neighborKey) || newCost < costSoFar.get(neighborKey)!) {
                        costSoFar.set(neighborKey, newCost);
                        queue.push(neighbor);
                        if (!reachable.some(r => r.equals(neighbor))) {
                            reachable.push(neighbor);
                        }
                    }
                }
            });
        }

        return reachable;
    }
}
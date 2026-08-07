// src/core/SimpleAI.ts
import { HexGrid } from '../HexGrid';
import { Pathfinder } from '../Pathfinder';
import { Unit } from '../entities/Unit';
import { HexNode } from '../HexNode';

export interface AIPlan {
    path: HexNode[];
    targetToAttack: Unit | null;
}

export class SimpleAI {
    /**
     * 計算敵方單位的 AI 行動計畫（路徑與目標）
     */
    public static executeTurnPlan(grid: HexGrid, enemy: Unit, allUnits: Unit[]): AIPlan {
        if (enemy.hasActed || enemy.hp <= 0) return { path: [], targetToAttack: null };

        // 1. 篩選場上活著的我方單位
        const playerUnits = allUnits.filter(u => u.faction === 'PLAYER' && u.hp > 0);
        if (playerUnits.length === 0) {
            return { path: [], targetToAttack: null };
        }

        // 2. 尋找距離最近的我方目標
        let closestPlayer: Unit = playerUnits[0];
        let minDistance = grid.getDistance(enemy.node, closestPlayer.node);

        for (let i = 1; i < playerUnits.length; i++) {
            const dist = grid.getDistance(enemy.node, playerUnits[i].node);
            if (dist < minDistance) {
                minDistance = dist;
                closestPlayer = playerUnits[i];
            }
        }

        let plannedPath: HexNode[] = [];

        // 3. 移動決策：如果不在攻擊射程內，計算移動路徑
                if (minDistance > enemy.job.attackRangeMax) {
                    // 排除其他單位佔用的節點，但目標玩家的節點除外（AI 只需移動到目標附近即可攻擊）
                    const occupiedNodes = allUnits
                        .filter(u => u !== enemy && u !== closestPlayer)
                        .map(u => u.node);
                    const fullPath = Pathfinder.findPath(grid, enemy.node, closestPlayer.node, Infinity, occupiedNodes);
            
            if (fullPath.length > 0) {
                const walkablePath = fullPath.filter(node => !node.equals(closestPlayer.node));
                const moveStep = Math.min(enemy.job.maxMovement, walkablePath.length);
                if (moveStep > 0) {
                    const destinationNode = walkablePath[moveStep - 1];
                    const isOccupied = allUnits.some(u => u.node.equals(destinationNode) && u !== enemy);
                    if (!isOccupied) {
                        plannedPath = walkablePath.slice(0, moveStep);
                    }
                }
            }
        }

        // 4. 攻擊決策：根據最終預計抵達的位置判定是否在射程內
        const finalNode = plannedPath.length > 0 ? plannedPath[plannedPath.length - 1] : enemy.node;
        const currentDistance = grid.getDistance(finalNode, closestPlayer.node);

        let targetToAttack: Unit | null = null;
        if (currentDistance >= enemy.job.attackRangeMin && currentDistance <= enemy.job.attackRangeMax) {
            targetToAttack = closestPlayer;
        }

        return { path: plannedPath, targetToAttack };
    }
}

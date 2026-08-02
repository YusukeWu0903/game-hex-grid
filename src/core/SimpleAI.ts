// src/core/SimpleAI.ts
import { HexGrid } from '../HexGrid';
import { Pathfinder } from '../Pathfinder';
import { Unit } from '../entities/Unit';
import { HexNode } from '../HexNode';

export class SimpleAI {
    /**
     * 執行單一敵方單位的 AI 行動決策
     * @returns 回傳 AI 移動後的目標位置 (若有移動)
     */
    public static executeTurn(grid: HexGrid, enemy: Unit, allUnits: Unit[]): { moved: boolean, targetAttacked: Unit | null } {
        if (enemy.hasActed || enemy.hp <= 0) return { moved: false, targetAttacked: null };

        // 1. 篩選場上活著的我方單位
        const playerUnits = allUnits.filter(u => u.faction === 'PLAYER' && u.hp > 0);
        if (playerUnits.length === 0) {
            enemy.hasActed = true;
            return { moved: false, targetAttacked: null };
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

        // 3. 移動決策：如果不在攻擊射程內，嘗試向目標靠近
        let hasMoved = false;
        if (minDistance > enemy.job.attackRangeMax) {
            // 用 A* 尋找出走向目標的最短路徑
            const fullPath = Pathfinder.findPath(grid, enemy.node, closestPlayer.node);
            
            if (fullPath.length > 0) {
                // 扣除目標本身所在的格子 (不能踩在別的單位身上)
                const walkablePath = fullPath.filter(node => !node.equals(closestPlayer.node));
                
                // 根據敵人的最大移動力限制，決定這回合能走到的最遠格子
                const moveStep = Math.min(enemy.job.maxMovement, walkablePath.length);
                if (moveStep > 0) {
                    const destinationNode = walkablePath[moveStep - 1];
                    
                    // 確保目標格沒有被其他單位佔據
                    const isOccupied = allUnits.some(u => u.node.equals(destinationNode) && u !== enemy);
                    if (!isOccupied) {
                        enemy.node = destinationNode;
                        hasMoved = true;
                    }
                }
            }
        }

        // 4. 攻擊決策：重新計算移動後的距離，若在射程內則發動攻擊
        let attackedUnit: Unit | null = null;
        const currentDistance = grid.getDistance(enemy.node, closestPlayer.node);
        
        if (currentDistance >= enemy.job.attackRangeMin && currentDistance <= enemy.job.attackRangeMax) {
            const damage = 3; // AI 基礎攻擊力
            const isDead = closestPlayer.takeDamage(damage);
            attackedUnit = closestPlayer;
            console.log(`🤖 AI 敵方 ${enemy.id} 攻擊了我方 ${closestPlayer.id}！造成 ${damage} 點傷害。`);
            
            if (isDead) {
                console.log(`💀 我方單位 ${closestPlayer.id} 陣亡了！`);
            }
        }

        // 標記 AI 行動結束
        enemy.hasActed = true;
        return { moved: hasMoved, targetAttacked: attackedUnit };
    }
}
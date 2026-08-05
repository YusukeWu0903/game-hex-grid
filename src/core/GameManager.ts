// src/core/GameManager.ts
import { GameState } from './GameState';
import { Unit } from '../entities/Unit';
import { HexGrid } from '../HexGrid';
import { SimpleAI } from './SimpleAI';
import { HexNode } from '../HexNode';

export class GameManager {
    public state: GameState = GameState.INIT;
    public turnCount: number = 1;
    public units: Unit[] = [];
    private grid: HexGrid | null = null;

    // 當狀態改變或資料更新時觸發的繪圖通知
    public onRenderNeeded?: () => void;

    // 當回合階段切換時觸發的動畫通知 (PLAYER / ENEMY / NEUTRAL)
    public onPhaseChange?: (phase: 'PLAYER' | 'ENEMY' | 'NEUTRAL') => void;

    // 敵方單位平滑移動動畫回調
    public onAnimateMovement?: (unit: Unit, path: HexNode[], onComplete: () => void) => void;
    
    public setGrid(grid: HexGrid) {
        this.grid = grid;
    }

    public addUnit(unit: Unit) {
        this.units.push(unit);
    }

    public startGame() {
        console.log("=== 遊戲系統初始化 ===");
        this.changeState(GameState.TURN_START);
    }

    private processState() {
        switch (this.state) {
            case GameState.TURN_START:
                console.log(`=== 第 ${this.turnCount} 回合 開始 ===`);
                this.units.forEach(u => u.resetAction());

                if (this.onRenderNeeded) this.onRenderNeeded();

                // 觸發「我方回合」過場動畫 (新回合開始時只播一次)
                if (this.onPhaseChange) this.onPhaseChange('PLAYER');

                this.changeState(GameState.PLAYER_PHASE);
                break;

            case GameState.PLAYER_PHASE:
                console.log("等待玩家操作...");
                break;
            
            case GameState.ENEMY_PHASE:
                console.log("敵方回合 (AI 思考與行動中...)");
                if (this.onPhaseChange) this.onPhaseChange('ENEMY');
                this.executeEnemyPhaseAsync();
                break;

            case GameState.NEUTRAL_PHASE:
                console.log("第三方勢力回合...");
                if (this.onPhaseChange) this.onPhaseChange('NEUTRAL');
                setTimeout(() => {
                    if (this.grid) {
                        const neutralUnits = this.units.filter(u => u.faction === 'NEUTRAL' && u.hp > 0);
                        neutralUnits.forEach(_neutral => {
                            if (this.state === GameState.GAME_OVER) return;
                            this.checkWinLossCondition();
                        });
                        this.units = this.units.filter(u => u.hp > 0);
                    }

                    if (this.onRenderNeeded) this.onRenderNeeded();

                    if (this.state !== GameState.GAME_OVER) {
                        this.changeState(GameState.TURN_END);
                    }
                }, 500);
                break;

            case GameState.TURN_END:
                console.log(`=== 第 ${this.turnCount} 回合 結束 ===`);
                this.turnCount++;
                this.changeState(GameState.TURN_START);
                break;
        }
    }

    private async executeEnemyPhaseAsync() {
        if (!this.grid) return;
        const enemyUnits = this.units.filter(u => u.faction === 'ENEMY' && u.hp > 0);

        for (const enemy of enemyUnits) {
            if (this.state === GameState.GAME_OVER) break;

            const aiPlan = SimpleAI.executeTurnPlan(this.grid, enemy, this.units);

            // 如果有移動路徑，呼叫動畫回調讓敵方單位沿著格子平滑移動
            if (aiPlan.path.length > 0 && this.onAnimateMovement) {
                await new Promise<void>((resolve) => {
                    this.onAnimateMovement!(enemy, aiPlan.path, resolve);
                });
            } else if (aiPlan.path.length > 0) {
                // 若無動畫回調則直接瞬移到終點
                enemy.node = aiPlan.path[aiPlan.path.length - 1];
            }

            // 執行攻擊
            if (aiPlan.targetToAttack) {
                const damage = 3;
                const isDead = aiPlan.targetToAttack.takeDamage(damage);
                console.log(`🤖 AI 敵方 ${enemy.id} 攻擊了我方 ${aiPlan.targetToAttack.id}！造成 ${damage} 點傷害。`);
                if (isDead) {
                    console.log(`💀 我方單位 ${aiPlan.targetToAttack.id} 陣亡了！`);
                }
            }

            enemy.hasActed = true;
            this.checkWinLossCondition();
            if (this.onRenderNeeded) this.onRenderNeeded();

            // 每個敵人行動之間的間隔
            await new Promise(r => setTimeout(r, 400));
        }

        this.units = this.units.filter(u => u.hp > 0);
        if (this.onRenderNeeded) this.onRenderNeeded();

        if (this.state !== GameState.GAME_OVER) {
            const hasNeutral = this.units.some(u => u.faction === 'NEUTRAL' && u.hp > 0);
            if (hasNeutral) {
                this.changeState(GameState.NEUTRAL_PHASE);
            } else {
                this.changeState(GameState.TURN_END);
            }
        }
    }

    public changeState(newState: GameState) {
        this.state = newState;
        this.processState();
    }

    public checkWinLossCondition(): boolean {
        const alivePlayerUnits = this.units.filter(u => u.faction === 'PLAYER' && u.hp > 0);
        const aliveEnemyUnits = this.units.filter(u => u.faction === 'ENEMY' && u.hp > 0);

        if (aliveEnemyUnits.length === 0) {
            console.log("🎉🎉🎉【 VICTORY 】全數敵方單位已被擊敗！玩家獲勝！🎉🎉🎉");
            this.changeState(GameState.GAME_OVER);
            return true;
        }

        if (alivePlayerUnits.length === 0) {
            console.log("💀💀💀【 DEFEAT 】我方單位已全數陣亡！戰鬥失敗！💀💀💀");
            this.changeState(GameState.GAME_OVER);
            return true;
        }

        return false;
    }

    public checkPlayerTurnEnd() {
        if (this.checkWinLossCondition()) return;

        const playerUnits = this.units.filter(u => u.faction === 'PLAYER' && u.hp > 0);
        const allActed = playerUnits.every(u => u.hasActed);
        
        if (allActed) {
            console.log("我方全員行動完畢，回合交接！");
            this.changeState(GameState.ENEMY_PHASE);
        } else {
            this.changeState(GameState.PLAYER_PHASE);
        }
    }
}

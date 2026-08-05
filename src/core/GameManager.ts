// src/core/GameManager.ts
import { GameState } from './GameState';
import { Unit } from '../entities/Unit';
import { HexGrid } from '../HexGrid';
import { SimpleAI } from './SimpleAI';

export class GameManager {
    public state: GameState = GameState.INIT;
    public turnCount: number = 1;
    public units: Unit[] = [];
    private grid: HexGrid | null = null;

    // 新增：當狀態改變或資料更新時觸發的繪圖通知
    public onRenderNeeded?: () => void;
    
    // 新增傳入 grid 引用以利 AI 尋路
    public setGrid(grid: HexGrid) {
        this.grid = grid;
    }

    // 將單位加入遊戲
    public addUnit(unit: Unit) {
        this.units.push(unit);
    }

    // 啟動遊戲迴圈
    public startGame() {
        console.log("=== 遊戲系統初始化 ===");
        this.changeState(GameState.TURN_START);
    }

    // 推進狀態機的核心邏輯
    private processState() {
        switch (this.state) {
            case GameState.TURN_START:
                console.log(`=== 第 ${this.turnCount} 回合 開始 ===`);
                // 將場上所有單位的行動狀態重置
                this.units.forEach(u => u.resetAction());

                // 通知畫面重新渲染 (讓角色從灰色恢復為藍色)
                if (this.onRenderNeeded) this.onRenderNeeded();

                // 自動進入玩家回合
                this.changeState(GameState.PLAYER_PHASE);
                break;

            case GameState.PLAYER_PHASE:
                console.log("等待玩家操作...");
                // 這裡會停住，等待 main.ts 傳遞滑鼠點擊事件進來
                break;
            
            case GameState.ENEMY_PHASE:
                console.log("敵方回合 (AI 思考與行動中...)");
                setTimeout(() => {
                    if (this.grid) {
                        const enemyUnits = this.units.filter(u => u.faction === 'ENEMY' && u.hp > 0);
                        
                        enemyUnits.forEach(enemy => {
                            if (this.state === GameState.GAME_OVER) return;
                            SimpleAI.executeTurn(this.grid!, enemy, this.units);
                            this.checkWinLossCondition();
                        });

                        this.units = this.units.filter(u => u.hp > 0);
                    }

                    if (this.onRenderNeeded) this.onRenderNeeded();

                    // 關鍵修改：敵方結束後，改進入第三方回合
                    if (this.state !== GameState.GAME_OVER) {
                        this.changeState(GameState.NEUTRAL_PHASE);
                    }
                }, 800);
                break;

            case GameState.NEUTRAL_PHASE:
                console.log("第三方勢力回合...");
                setTimeout(() => {
                    if (this.grid) {
                        const neutralUnits = this.units.filter(u => u.faction === 'NEUTRAL' && u.hp > 0);
                        
                        neutralUnits.forEach(_neutral => {
                            if (this.state === GameState.GAME_OVER) return;
                            // 未來可以在此處掛載 SimpleAI 或獨立的中立 AI 邏輯
                            this.checkWinLossCondition();
                        });

                        this.units = this.units.filter(u => u.hp > 0);
                    }

                    if (this.onRenderNeeded) this.onRenderNeeded();

                    // 第三方結束後，才進入回合結算
                    if (this.state !== GameState.GAME_OVER) {
                        this.changeState(GameState.TURN_END);
                    }
                }, 500);
                break;

            case GameState.TURN_END:
                console.log(`=== 第 ${this.turnCount} 回合 結束 ===`);
                this.turnCount++;
                // 進入下一個回合
                this.changeState(GameState.TURN_START);
                break;
        }
    }

    // 改變狀態的統一入口
    public changeState(newState: GameState) {
        this.state = newState;
        this.processState();
    }

    // 檢查勝負條件
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

    // 檢查是否所有我方單位都已行動完畢
    public checkPlayerTurnEnd() {
        // 關鍵修正：在檢查回合結束前，必須先判斷敵人是否已被全滅！
        if (this.checkWinLossCondition()) return;

        const playerUnits = this.units.filter(u => u.faction === 'PLAYER' && u.hp > 0);
        const allActed = playerUnits.every(u => u.hasActed);
        
        if (allActed) {
            console.log("我方全員行動完畢，回合交接！");
            this.changeState(GameState.ENEMY_PHASE);
        } else {
            // 退回等待操作狀態
            this.changeState(GameState.PLAYER_PHASE);
        }
    }
}
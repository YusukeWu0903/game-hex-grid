import { HexGrid } from './HexGrid';
import { IsoHexRenderer } from './IsoHexRenderer';
import { Pathfinder } from './Pathfinder';
import { HexNode } from './HexNode';
import { GameManager } from './core/GameManager';
import { GameState } from './core/GameState';
import { Unit } from './entities/Unit';
import { JOB_DATA } from './entities/Job';
import type { Skill } from './entities/Job'; // 使用 import type

// ==========================================
// 1. 基礎地圖與渲染器初始化
// ==========================================
const grid = new HexGrid();
grid.generateHexagonMap(4);
const renderer = new IsoHexRenderer('gameCanvas', 55);
const canvas = document.getElementById('gameCanvas') as HTMLCanvasElement;

// ==========================================
// 2. 狀態變數與範圍更新 (必須先宣告，避免 TDZ 錯誤)
// ==========================================
let selectedUnit: Unit | null = null; 
let selectedSkill: Skill | null = null; // 新增：目前準備施放的技能 (null 代表普通攻擊)
let actionMode: 'MOVE' | 'ATTACK' = 'MOVE';
let currentPath: HexNode[] = [];
let reachableNodes: HexNode[] = [];
let attackableNodes: HexNode[] = [];

// 建立大腦實體
const gameManager = new GameManager();
gameManager.setGrid(grid);

// 建立場上單位
const p1 = new Unit('P1', grid.getNode(0, 0, 0)!, JOB_DATA['劍士'], 'PLAYER', 10);
const p2 = new Unit('P2', grid.getNode(-1, 0, 1)!, JOB_DATA['弓箭手'], 'PLAYER', 10);
const e1 = new Unit('E1', grid.getNode(2, -1, -1)!, JOB_DATA['劍士'], 'ENEMY', 8);

gameManager.addUnit(p1);
gameManager.addUnit(p2);
gameManager.addUnit(e1);

// ==========================================
// 3. 畫面渲染控制函式
// ==========================================
function updateRanges() {
    reachableNodes = [];
    attackableNodes = [];

    if (!selectedUnit || selectedUnit.hasActed) return;

    if (actionMode === 'MOVE') {
        reachableNodes = Pathfinder.getReachableNodes(grid, selectedUnit.node, selectedUnit.job.maxMovement);
    } else if (actionMode === 'ATTACK') {
        // 判定使用的射程：優先使用選中的技能射程，若無則使用職業普攻射程
        const minR = selectedSkill ? selectedSkill.rangeMin : selectedUnit.job.attackRangeMin;
        const maxR = selectedSkill ? selectedSkill.rangeMax : selectedUnit.job.attackRangeMax;

        grid.getNodes().forEach(n => {
            const dist = grid.getDistance(selectedUnit!.node, n);
            if (dist >= minR && dist <= maxR && !n.equals(selectedUnit!.node)) {
                attackableNodes.push(n);
            }
        });
    }
}

function renderGame() {
    renderer.render(grid, currentPath, reachableNodes, gameManager.units, attackableNodes);

    // 新增：繪製 HUD 資訊
    const stateTextMap: Record<string, string> = {
        'TURN_START': '回合開始',
        'PLAYER_PHASE': '我方回合',
        'UNIT_SELECTED': '我方回合',
        'ENEMY_PHASE': '敵方回合',
        'NEUTRAL_PHASE': '第三方回合',
        'TURN_END': '回合結算',  // <--- 正確呈現「回合結算」或「過渡中」
        'GAME_OVER': '戰鬥結束'
    };
    renderer.drawHUD(gameManager.turnCount, stateTextMap[gameManager.state] || gameManager.state);

    // 新增：若 GAME_OVER 則疊加結算畫面
    if (gameManager.state === GameState.GAME_OVER) {
        const isVictory = gameManager.units.some(u => u.faction === 'PLAYER' && u.hp > 0);
        renderer.drawGameOver(isVictory);
    }
}

// 綁定大腦通知 (此時 updateRanges 與 reachableNodes 已經定義完畢，可安全調用)
gameManager.onRenderNeeded = () => {
    updateRanges();
    renderGame();
};

// 當視窗大小改變時，重新繪製畫面以確保置中
window.addEventListener('resize', () => {
    renderGame();
});

// ==========================================
// 4. 正式啟動遊戲大腦
// ==========================================
gameManager.startGame();

// ==========================================
// 5. 事件監聽 (含 GAME_OVER 狀態阻擋)
// ==========================================

canvas.addEventListener('mousemove', (event) => {
    if (gameManager.state === GameState.GAME_OVER) return;
    if (gameManager.state !== GameState.PLAYER_PHASE && gameManager.state !== GameState.UNIT_SELECTED) return;
    if (!selectedUnit || selectedUnit.hasActed) return;

    const rect = canvas.getBoundingClientRect();
    const cubeCoords = renderer.pixelToHex(event.clientX - rect.left, event.clientY - rect.top);
    const targetNode = grid.getNode(cubeCoords.x, cubeCoords.y, cubeCoords.z);

    currentPath = [];
    if (targetNode && !targetNode.equals(selectedUnit.node) && actionMode === 'MOVE') {
        currentPath = Pathfinder.findPath(grid, selectedUnit.node, targetNode, selectedUnit.job.maxMovement);
    }

    renderGame();
});

canvas.addEventListener('click', (event) => {
    // 若遊戲已結束，拒絕任何操作
    if (gameManager.state === GameState.GAME_OVER) {
        console.log("遊戲已結束！無法進行操作。");
        return;
    }
    
    if (gameManager.state !== GameState.PLAYER_PHASE && gameManager.state !== GameState.UNIT_SELECTED) return;

    const rect = canvas.getBoundingClientRect();
    const cubeCoords = renderer.pixelToHex(event.clientX - rect.left, event.clientY - rect.top);
    const clickedNode = grid.getNode(cubeCoords.x, cubeCoords.y, cubeCoords.z);

    if (!clickedNode) return;

    const clickedUnit = gameManager.units.find(u => u.node.equals(clickedNode));

    // 【情境 1】：選擇 / 切換我方未行動的角色 (補上 actionMode === 'MOVE' 限制，防止移動後點自己誤觸切換)
    if (clickedUnit && clickedUnit.faction === 'PLAYER' && !clickedUnit.hasActed && actionMode === 'MOVE') {
        selectedUnit = clickedUnit;
        gameManager.changeState(GameState.UNIT_SELECTED);
        actionMode = 'MOVE';
        updateRanges();
        renderGame();
        console.log(`🎯 選中我方單位：${selectedUnit.id} (${selectedUnit.job.name}) | 移動力: ${selectedUnit.job.maxMovement}`);
        return;
    }

    if (!selectedUnit) return;

    // 【情境 2】：尚未移動時，點擊自己原位 -> 直接切換成攻擊/待命模式
    if (clickedNode.equals(selectedUnit.node) && actionMode === 'MOVE') {
        actionMode = 'ATTACK';
        updateRanges();
        renderGame();
        console.log(`${selectedUnit.id} 原地待命，切換至攻擊模式`);
        return;
    }

    // 【情境 3】：移動階段
    if (actionMode === 'MOVE') {
        const isReachable = reachableNodes.some(r => r.equals(clickedNode));
        if (isReachable && clickedNode.isWalkable && !clickedUnit) {
            
            // ✏️ 新增：計算這趟路徑的總地形 Cost
            const movePath = Pathfinder.findPath(grid, selectedUnit.node, clickedNode, selectedUnit.job.maxMovement);
            let totalCost = 0;
            movePath.forEach(n => {
                totalCost += Pathfinder.getTerrainCost(n);
            });

            selectedUnit.node = clickedNode;
            currentPath = [];
            actionMode = 'ATTACK';
            updateRanges();

            console.log(`🚶 ${selectedUnit.id} 移動完成！途經 ${movePath.length} 格 | 總消耗 Cost: ${totalCost} / ${selectedUnit.job.maxMovement}`);
            console.log(`⚔️ 切換至攻擊模式 (點擊敵人攻擊，或點擊自己/空白處待命)`);
        } else {
            // 點擊無效區域，取消選取該角色
            selectedUnit = null;
            updateRanges();
            gameManager.changeState(GameState.PLAYER_PHASE);
        }
    } 
    // 【情境 4】：攻擊階段 (含移動後點擊自己/空白處結算)
    else if (actionMode === 'ATTACK') {
        const isAttackable = attackableNodes.some(a => a.equals(clickedNode));
        
        // 情況 4A：點擊了攻擊範圍內的敵方單位
        if (isAttackable && clickedUnit && clickedUnit.faction === 'ENEMY') {
            let baseDamage = 4;
            let finalDamage = baseDamage;

            // 若選擇了技能，嘗試扣除 MP 並計算技能傷害
            if (selectedSkill) {
                if (selectedUnit.useMp(selectedSkill.mpCost)) {
                    finalDamage = Math.round(baseDamage * selectedSkill.damageMultiplier);
                    console.log(`✨ ${selectedUnit.id} 消耗了 ${selectedSkill.mpCost} MP，施展技能【${selectedSkill.name}】！`);
                } else {
                    console.log(`⚠️ MP 不足 (需要 ${selectedSkill.mpCost})，轉為普通攻擊！`);
                }
            }

            const isDead = clickedUnit.takeDamage(finalDamage);
            
            // ✏️ 新增這行：顯示傷害飄字動畫
            renderer.addFloatingText(clickedUnit.node, `-${finalDamage}`, '#ff1744');

            console.log(`${selectedUnit.id} 對 ${clickedUnit.id} 造成 ${finalDamage} 點傷害！`);
            
            if (isDead) {
                console.log(`💀 ${clickedUnit.id} 被擊敗了！`);
                gameManager.units = gameManager.units.filter(u => u !== clickedUnit);
            }
        }
        // 情況 4B：移動後點擊了自己 -> 視為「結束攻擊直接待命」
        else if (clickedNode.equals(selectedUnit.node)) {
            console.log(`${selectedUnit.id} 在新位置選擇待命，結束本回合行動。`);
        }
        // 情況 4C：點擊了無效或非攻擊目標區域
        else {
            console.log(`${selectedUnit.id} 未選擇有效攻擊目標，直接待命。`);
        }
        
        // 重置選取狀態與技能
        selectedUnit.hasActed = true;
        selectedUnit = null;
        selectedSkill = null; // <--- 新增此行：重置技能選取
        actionMode = 'MOVE';
        updateRanges();
        
        // 檢查勝負與回合交接
        gameManager.checkPlayerTurnEnd();
    }

    renderGame();
});

window.addEventListener('keydown', (event) => {
    if (!selectedUnit || actionMode !== 'ATTACK') return;

    // 按下數字鍵 1：切換使用技能 1
    if (event.key === '1') {
        const skill = selectedUnit.job.skills[0];
        if (skill) {
            // 切換技能選取狀態 (若已選中則取消)
            selectedSkill = selectedSkill === skill ? null : skill;
            
            if (selectedSkill) {
                console.log(`已準備技能：【${selectedSkill.name}】(消耗 ${selectedSkill.mpCost} MP)`);
            } else {
                console.log("切換回普通攻擊");
            }
            
            updateRanges();
            renderGame();
        }
    }
});

// 啟動 60 FPS 動畫渲染迴圈 (讓飄字與動畫連續更新)
function gameLoop() {
    renderGame();
    requestAnimationFrame(gameLoop);
}
gameLoop();
import { HexGrid } from './HexGrid';
import { IsoHexRenderer } from './IsoHexRenderer';
import { Pathfinder } from './Pathfinder';
import { HexNode } from './HexNode';
import type { TerrainType } from './HexNode';
import { GameManager } from './core/GameManager';
import { GameState } from './core/GameState';
import { Unit } from './entities/Unit';
import { JOB_DATA } from './entities/Job';
import type { Skill } from './entities/Job';
import { LevelManager } from './LevelManager';
import { EnemyRegistry } from './data/EnemyRegistry';

// ==========================================
// 1. 基礎地圖與渲染器初始化
// ==========================================
const grid = new HexGrid();
grid.generateHexagonMap(4);
const renderer = new IsoHexRenderer('gameCanvas', 55);
const canvas = document.getElementById('gameCanvas') as HTMLCanvasElement;

// ==========================================
// 2. 模式狀態與編輯器變數
// ==========================================
let currentMode: 'MENU' | 'LEVEL_EDITOR' | 'MAP_EDITOR' | 'GAME' = 'MENU';
let selectedUnit: Unit | null = null; 
let selectedSkill: Skill | null = null;
let actionMode: 'MOVE' | 'ATTACK' = 'MOVE';
let currentPath: HexNode[] = [];
let reachableNodes: HexNode[] = [];
let attackableNodes: HexNode[] = [];

// 目前編輯中的地圖 ID
let currentEditingMapId: string = 'map_tutorial';

// 筆刷狀態
let activeBrushType: 'TERRAIN' | 'SPAWN' = 'TERRAIN';
let activeTerrain: TerrainType = 'PLAIN';
let activeSpawn: 'PLAYER' | 'ENEMY' | 'CLEAR' = 'PLAYER';

// 建立大腦實體
const gameManager = new GameManager();
gameManager.setGrid(grid);

// ==========================================
// 3. UI 元素與事件綁定 (路由與選單切換)
// ==========================================
const mainMenu = document.getElementById('main-menu') as HTMLElement;
const levelEditorPanel = document.getElementById('level-editor-panel') as HTMLElement;
const mapEditorPanel = document.getElementById('map-editor-panel') as HTMLElement;
const gamePanel = document.getElementById('game-panel') as HTMLElement;
const selectMapBind = document.getElementById('select-map-bind') as HTMLSelectElement;

// 更新地圖下拉選單選項
function refreshMapDropdown() {
    if (!selectMapBind) return;
    selectMapBind.innerHTML = '';
    const maps = LevelManager.getSavedMaps();
    maps.forEach(m => {
        const option = document.createElement('option');
        option.value = m.mapId;
        option.textContent = `${m.name} (${m.mapId})`;
        if (m.mapId === currentEditingMapId) {
            option.selected = true;
        }
        selectMapBind.appendChild(option);
    });
}

// 從主選單進入關卡編輯器
document.getElementById('btn-open-editor')?.addEventListener('click', () => {
    currentMode = 'LEVEL_EDITOR';
    mainMenu.style.display = 'none';
    levelEditorPanel.style.display = 'flex';
    mapEditorPanel.style.display = 'none';
    gamePanel.style.display = 'none';
    selectedUnit = null;
    refreshMapDropdown();
    renderGame();
    console.log("📋 進入關卡編輯器模式");
});

// 從關卡編輯器點擊「編輯此地圖」進入地圖編輯器
document.getElementById('btn-edit-map')?.addEventListener('click', () => {
    currentEditingMapId = selectMapBind.value || 'map_tutorial';
    const mapData = LevelManager.getMap(currentEditingMapId);
    if (mapData) {
        LevelManager.applyMapToGrid(mapData, grid);
    }
    
    currentMode = 'MAP_EDITOR';
    levelEditorPanel.style.display = 'none';
    mapEditorPanel.style.display = 'flex';
    
    const editingMapNameEl = document.getElementById('editing-map-name');
    if (editingMapNameEl) editingMapNameEl.textContent = currentEditingMapId;

    renderGame();
    console.log(`🗺️ 進入地圖編輯器子模組：編輯地圖 [${currentEditingMapId}]`);
});

// 從地圖編輯器點擊「儲存並返回」
document.getElementById('btn-back-level-editor')?.addEventListener('click', () => {
    // 自動儲存目前網格至當前編輯的地圖中
    const mapObj = LevelManager.getMap(currentEditingMapId);
    const mapName = mapObj ? mapObj.name : currentEditingMapId;
    LevelManager.saveMap(currentEditingMapId, mapName, 4, grid);

    currentMode = 'LEVEL_EDITOR';
    mapEditorPanel.style.display = 'none';
    levelEditorPanel.style.display = 'flex';
    refreshMapDropdown();
    renderGame();
    console.log(`💾 地圖 [${currentEditingMapId}] 已自動儲存，返回關卡編輯器`);
});

// 啟動遊戲 (直接從主選單)
document.getElementById('btn-start-game')?.addEventListener('click', () => {
    const { map } = LevelManager.getDefaultTestLevel();
    startGameMode(map.mapId);
});

// 啟動遊戲 (從關卡編輯器測試執行)
document.getElementById('btn-test-level')?.addEventListener('click', () => {
    const selectedMapId = selectMapBind.value || 'map_tutorial';
    startGameMode(selectedMapId);
});

function startGameMode(mapId: string) {
    currentMode = 'GAME';
    mainMenu.style.display = 'none';
    levelEditorPanel.style.display = 'none';
    mapEditorPanel.style.display = 'none';
    gamePanel.style.display = 'flex';

    // 載入指定的綁定地圖
    const mapData = LevelManager.getMap(mapId);
    if (mapData) {
        LevelManager.applyMapToGrid(mapData, grid);
    } else {
        const { map } = LevelManager.getDefaultTestLevel();
        LevelManager.applyMapToGrid(map, grid);
    }

    // 取得關卡設定
    const { level } = LevelManager.getDefaultTestLevel();
    const levelNameInput = document.getElementById('input-level-name') as HTMLInputElement;
    if (levelNameInput) level.name = levelNameInput.value;

    const winCondSelect = document.getElementById('select-win-cond') as HTMLSelectElement;
    if (winCondSelect) level.winCondition = winCondSelect.value;

    const loseCondSelect = document.getElementById('select-lose-cond') as HTMLSelectElement;
    if (loseCondSelect) level.loseCondition = loseCondSelect.value;

    // 清空並生成單位
    gameManager.units = [];

    // 1. 根據地圖上的 'PLAYER' 出生點自動生成我方單位
    const playerSpawnNodes = grid.getNodes().filter(n => n.spawnPoint === 'PLAYER');
    if (playerSpawnNodes.length > 0) {
        const p1 = new Unit('P1', playerSpawnNodes[0], JOB_DATA['劍士'], 'PLAYER', 10);
        gameManager.addUnit(p1);
    }
    if (playerSpawnNodes.length > 1) {
        const p2 = new Unit('P2', playerSpawnNodes[1], JOB_DATA['弓箭手'], 'PLAYER', 10);
        gameManager.addUnit(p2);
    }

    // 若未設定玩家出生點，預設放保底位置
    if (gameManager.units.length === 0) {
        gameManager.addUnit(new Unit('P1', grid.getNode(0, 0, 0)!, JOB_DATA['劍士'], 'PLAYER', 10));
    }

    // 2. 嚴格根據地圖上的 'ENEMY' 出生點生成敵方單位
    const enemySpawnNodes = grid.getNodes().filter(n => n.spawnPoint === 'ENEMY');
    enemySpawnNodes.forEach((node, index) => {
        const rosterItem = level.enemyRoster[index] || level.enemyRoster[0] || { enemyId: 'enemy_swordsman_base' };
        const enemy = EnemyRegistry.createEnemyUnit(rosterItem.enemyId, node, `E${index + 1}`);
        gameManager.addUnit(enemy);
    });

    selectedUnit = null;
    selectedSkill = null;
    actionMode = 'MOVE';
    gameManager.startGame();
    renderGame();
    console.log(`🎮 啟動關卡 [${level.name}] (綁定地圖: ${mapId})`);
}

// 返回主選單
document.querySelectorAll('#btn-level-back-menu, #btn-game-back').forEach(btn => {
    btn.addEventListener('click', () => {
        currentMode = 'MENU';
        mainMenu.style.display = 'flex';
        levelEditorPanel.style.display = 'none';
        mapEditorPanel.style.display = 'none';
        gamePanel.style.display = 'none';
        selectedUnit = null;
        renderGame();
        console.log("🏠 返回主選單");
    });
});

// 地形筆刷點擊綁定
document.querySelectorAll('#brush-group .brush-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
        document.querySelectorAll('#map-editor-panel .brush-btn').forEach(b => b.classList.remove('active'));
        const target = e.currentTarget as HTMLElement;
        target.classList.add('active');
        activeBrushType = 'TERRAIN';
        activeTerrain = target.getAttribute('data-terrain') as TerrainType;
        console.log(`🖌️ 切換地形筆刷：${activeTerrain}`);
    });
});

// 佈署點筆刷點擊綁定
document.querySelectorAll('#spawn-brush-group .brush-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
        document.querySelectorAll('#map-editor-panel .brush-btn').forEach(b => b.classList.remove('active'));
        const target = e.currentTarget as HTMLElement;
        target.classList.add('active');
        activeBrushType = 'SPAWN';
        activeSpawn = target.getAttribute('data-spawn') as any;
        console.log(`🚩 切換佈署點筆刷：${activeSpawn}`);
    });
});

// 匯出 JSON
document.getElementById('btn-export')?.addEventListener('click', () => {
    LevelManager.exportCurrentMapAsJSON(currentEditingMapId, `地圖_${currentEditingMapId}`, 4, grid);
});

// 匯入 JSON
const importFileInput = document.getElementById('import-file') as HTMLInputElement;
document.getElementById('btn-import')?.addEventListener('click', () => {
    importFileInput.click();
});

importFileInput.addEventListener('change', (e) => {
    const file = (e.target as HTMLInputElement).files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
        const content = event.target?.result as string;
        if (content) {
            const importedMap = LevelManager.importMapFromJSON(content);
            if (importedMap) {
                currentEditingMapId = importedMap.mapId;
                LevelManager.applyMapToGrid(importedMap, grid);
                renderGame();
                alert(`成功匯入並載入地圖：${importedMap.name}`);
            }
        }
    };
    reader.readAsText(file);
    importFileInput.value = '';
});

// ==========================================
// 4. 畫面渲染控制函式 (嚴格模式分離)
// ==========================================
function updateRanges() {
    reachableNodes = [];
    attackableNodes = [];

    if (currentMode !== 'GAME' || !selectedUnit || selectedUnit.hasActed) return;

    if (actionMode === 'MOVE') {
        reachableNodes = Pathfinder.getReachableNodes(grid, selectedUnit.node, selectedUnit.job.maxMovement);
    } else if (actionMode === 'ATTACK') {
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
    if (currentMode === 'MENU' || currentMode === 'LEVEL_EDITOR' || currentMode === 'MAP_EDITOR') {
        // 主選單與各編輯器模式：只繪製地圖網格 (無單位)
        renderer.render(grid, [], [], [], []);
    } else if (currentMode === 'GAME') {
        // 遊戲戰鬥模式：繪製網格、路徑、範圍、單位與 HUD
        renderer.render(grid, currentPath, reachableNodes, gameManager.units, attackableNodes);

        const stateTextMap: Record<string, string> = {
            'TURN_START': '回合開始',
            'PLAYER_PHASE': '我方回合',
            'UNIT_SELECTED': '我方回合',
            'ENEMY_PHASE': '敵方回合',
            'NEUTRAL_PHASE': '第三方回合',
            'TURN_END': '回合結算',
            'GAME_OVER': '戰鬥結束'
        };
        renderer.drawHUD(gameManager.turnCount, stateTextMap[gameManager.state] || gameManager.state);

        if (gameManager.state === GameState.GAME_OVER) {
            const isVictory = gameManager.units.some(u => u.faction === 'PLAYER' && u.hp > 0);
            renderer.drawGameOver(isVictory);
        }
    }
}

gameManager.onRenderNeeded = () => {
    updateRanges();
    renderGame();
};

window.addEventListener('resize', () => {
    renderGame();
});

// 初始渲染主選單畫面
renderGame();

// ==========================================
// 5. 事件監聽 (畫布互動：地圖編輯器塗刷 vs 遊戲戰鬥)
// ==========================================

canvas.addEventListener('mousemove', (event) => {
    if (currentMode !== 'GAME') return;
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
    const rect = canvas.getBoundingClientRect();
    const cubeCoords = renderer.pixelToHex(event.clientX - rect.left, event.clientY - rect.top);
    const clickedNode = grid.getNode(cubeCoords.x, cubeCoords.y, cubeCoords.z);

    if (!clickedNode) return;

    // 【模式 A：地圖編輯器子模組模式】地形或佈署點塗刷
    if (currentMode === 'MAP_EDITOR') {
        if (activeBrushType === 'TERRAIN') {
            clickedNode.terrain = activeTerrain;
            clickedNode.isWalkable = (activeTerrain !== 'MOUNTAIN' && activeTerrain !== 'WATER');
            console.log(`🎨 塗刷地形 [${activeTerrain}] 於 ${clickedNode.toString()}`);
        } else if (activeBrushType === 'SPAWN') {
            if (activeSpawn === 'CLEAR') {
                clickedNode.spawnPoint = null;
                console.log(`🧹 清除佈署點 於 ${clickedNode.toString()}`);
            } else {
                clickedNode.spawnPoint = activeSpawn;
                console.log(`🚩 設定佈署點 [${activeSpawn}] 於 ${clickedNode.toString()}`);
            }
        }
        renderGame();
        return;
    }

    // 【模式 B：遊戲戰鬥模式】
    if (currentMode === 'GAME') {
        if (gameManager.state === GameState.GAME_OVER) {
            console.log("遊戲已結束！");
            return;
        }

        if (gameManager.state !== GameState.PLAYER_PHASE && gameManager.state !== GameState.UNIT_SELECTED) return;

        const clickedUnit = gameManager.units.find(u => u.node.equals(clickedNode));

        // 1. 選擇 / 切換我方未行動的角色
        if (clickedUnit && clickedUnit.faction === 'PLAYER' && !clickedUnit.hasActed && actionMode === 'MOVE') {
            selectedUnit = clickedUnit;
            gameManager.changeState(GameState.UNIT_SELECTED);
            actionMode = 'MOVE';
            updateRanges();
            renderGame();
            console.log(`🎯 選中我方單位：${selectedUnit.id} (${selectedUnit.job.name})`);
            return;
        }

        if (!selectedUnit) return;

        // 2. 原地待命切換至攻擊模式
        if (clickedNode.equals(selectedUnit.node) && actionMode === 'MOVE') {
            actionMode = 'ATTACK';
            updateRanges();
            renderGame();
            console.log(`${selectedUnit.id} 原地待命，切換至攻擊模式`);
            return;
        }

        // 3. 移動階段
        if (actionMode === 'MOVE') {
            const isReachable = reachableNodes.some(r => r.equals(clickedNode));
            if (isReachable && clickedNode.isWalkable && !clickedUnit) {
                selectedUnit.node = clickedNode;
                currentPath = [];
                actionMode = 'ATTACK';
                updateRanges();
                console.log(`🚶 ${selectedUnit.id} 移動完成！`);
            } else {
                selectedUnit = null;
                updateRanges();
                gameManager.changeState(GameState.PLAYER_PHASE);
            }
        } 
        // 4. 攻擊階段
        else if (actionMode === 'ATTACK') {
            const isAttackable = attackableNodes.some(a => a.equals(clickedNode));
            
            if (isAttackable && clickedUnit && clickedUnit.faction === 'ENEMY') {
                let baseDamage = 4;
                let finalDamage = baseDamage;

                if (selectedSkill) {
                    if (selectedUnit.useMp(selectedSkill.mpCost)) {
                        finalDamage = Math.round(baseDamage * selectedSkill.damageMultiplier);
                        console.log(`✨ 施展技能【${selectedSkill.name}】！`);
                    }
                }

                const isDead = clickedUnit.takeDamage(finalDamage);
                renderer.addFloatingText(clickedUnit.node, `-${finalDamage}`, '#ff1744');
                console.log(`${selectedUnit.id} 對 ${clickedUnit.id} 造成 ${finalDamage} 點傷害！`);
                
                if (isDead) {
                    console.log(`💀 ${clickedUnit.id} 被擊敗了！`);
                    gameManager.units = gameManager.units.filter(u => u !== clickedUnit);
                }
            }
            
            selectedUnit.hasActed = true;
            selectedUnit = null;
            selectedSkill = null;
            actionMode = 'MOVE';
            updateRanges();
            gameManager.checkPlayerTurnEnd();
        }

        renderGame();
    }
});

window.addEventListener('keydown', (event) => {
    if (currentMode !== 'GAME' || !selectedUnit || actionMode !== 'ATTACK') return;

    if (event.key === '1') {
        const skill = selectedUnit.job.skills[0];
        if (skill) {
            selectedSkill = selectedSkill === skill ? null : skill;
            updateRanges();
            renderGame();
        }
    }
});

// 啟動 60 FPS 動畫迴圈
function gameLoop() {
    renderGame();
    requestAnimationFrame(gameLoop);
}
gameLoop();

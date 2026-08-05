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
import type { LevelData } from './data/GameSchema';

// ==========================================
// 1. 初始化系統與狀態
// ==========================================
const grid = new HexGrid();
const renderer = new IsoHexRenderer('gameCanvas', 55);
const canvas = document.getElementById('gameCanvas') as HTMLCanvasElement;

const gameManager = new GameManager();
gameManager.setGrid(grid);

let currentEditingMapId = 'map_tutorial';
let currentEditingMapName = '新手演練場';
let mapRadius = 4;

grid.generateHexagonMap(mapRadius);

const savedMaps = LevelManager.getSavedMaps();
if (savedMaps.length > 0) {
    const defaultMap = savedMaps[0];
    currentEditingMapId = defaultMap.mapId;
    currentEditingMapName = defaultMap.name;
    mapRadius = defaultMap.radius;
    LevelManager.applyMapToGrid(defaultMap, grid);
}

let currentMode: 'MENU' | 'LEVEL_EDITOR' | 'MAP_EDITOR' | 'GAME' = 'MENU';

const mainMenu = document.getElementById('main-menu') as HTMLElement;
const levelEditorPanel = document.getElementById('level-editor-panel') as HTMLElement;
const mapEditorPanel = document.getElementById('map-editor-panel') as HTMLElement;
const gamePanel = document.getElementById('game-panel') as HTMLElement;
const editingMapNameSpan = document.getElementById('editing-map-name') as HTMLElement;
const selectMapBind = document.getElementById('select-map-bind') as HTMLSelectElement;

let activeBrushType: 'TERRAIN' | 'SPAWN' = 'TERRAIN';
let activeTerrain: TerrainType = 'PLAIN';
let activeSpawn: 'PLAYER' | 'ENEMY' | 'CLEAR' | null = null;

let editingPlayerRoster: { jobKey: string; name?: string }[] = [
    { jobKey: '劍士', name: '我方劍士' },
    { jobKey: '弓箭手', name: '我方弓手' }
];
let editingEnemyRoster: { enemyId: string }[] = [
    { enemyId: 'enemy_swordsman_base' },
    { enemyId: 'enemy_archer_base' },
    { enemyId: 'enemy_heavy_guard' }
];

let selectedUnit: Unit | null = null;
let selectedSkill: Skill | null = null;
let actionMode: 'MOVE' | 'ATTACK' = 'MOVE';
let currentPath: HexNode[] = [];
let reachableNodes: HexNode[] = [];
let attackableNodes: HexNode[] = [];

// ==========================================
// 2. 畫面渲染控制函式
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
        renderer.render(grid, [], [], [], []);
    } else if (currentMode === 'GAME') {
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

gameManager.onAnimateMovement = (unit, path, onComplete) => {
    animateUnitMovement(unit, path, onComplete);
};

// 回合過場動畫
function showTurnBanner(phase: 'PLAYER' | 'ENEMY' | 'NEUTRAL') {
    const banner = document.getElementById('turn-banner');
    if (!banner) return;
    const phaseMap: Record<string, { text: string; color: string }> = {
        'PLAYER': { text: '⚔ 我方回合', color: '#38bdf8' },
        'ENEMY': { text: '⚔ 敵方回合', color: '#f87171' },
        'NEUTRAL': { text: '⚔ 第三方回合', color: '#fbbf24' }
    };
    const cfg = phaseMap[phase];
    banner.textContent = cfg.text;
    banner.style.color = cfg.color;
    banner.style.borderColor = cfg.color;
    banner.style.boxShadow = `0 0 40px rgba(0,0,0,0.7), 0 0 24px ${cfg.color}`;
    banner.classList.remove('show');
    void banner.offsetWidth;
    banner.classList.add('show');
}

gameManager.onPhaseChange = (phase) => {
    showTurnBanner(phase);
};

// ==========================================
// 3. 關卡編輯器 Roster UI 綁定
// ==========================================
function renderRosterUI() {
    const playerListDiv = document.getElementById('player-roster-list');
    const enemyListDiv = document.getElementById('enemy-roster-list');
    if (!playerListDiv || !enemyListDiv) return;

    playerListDiv.innerHTML = '';
    editingPlayerRoster.forEach((item, index) => {
        const row = document.createElement('div');
        row.className = 'roster-item';
        
        const select = document.createElement('select');
        Object.keys(JOB_DATA).forEach(jobKey => {
            const opt = document.createElement('option');
            opt.value = jobKey;
            opt.textContent = jobKey;
            if (jobKey === item.jobKey) opt.selected = true;
            select.appendChild(opt);
        });
        select.addEventListener('change', (e) => {
            editingPlayerRoster[index].jobKey = (e.target as HTMLSelectElement).value;
        });

        const delBtn = document.createElement('button');
        delBtn.className = 'roster-del-btn';
        delBtn.textContent = '刪除';
        delBtn.addEventListener('click', () => {
            editingPlayerRoster.splice(index, 1);
            renderRosterUI();
        });

        row.appendChild(select);
        row.appendChild(delBtn);
        playerListDiv.appendChild(row);
    });

    enemyListDiv.innerHTML = '';
    editingEnemyRoster.forEach((item, index) => {
        const row = document.createElement('div');
        row.className = 'roster-item';

        const select = document.createElement('select');
        const templates = EnemyRegistry.getAllTemplates();
        templates.forEach(tpl => {
            const opt = document.createElement('option');
            opt.value = tpl.enemyId;
            opt.textContent = `${tpl.name} (${tpl.jobKey})`;
            if (tpl.enemyId === item.enemyId) opt.selected = true;
            select.appendChild(opt);
        });
        select.addEventListener('change', (e) => {
            editingEnemyRoster[index].enemyId = (e.target as HTMLSelectElement).value;
        });

        const delBtn = document.createElement('button');
        delBtn.className = 'roster-del-btn';
        delBtn.textContent = '刪除';
        delBtn.addEventListener('click', () => {
            editingEnemyRoster.splice(index, 1);
            renderRosterUI();
        });

        row.appendChild(select);
        row.appendChild(delBtn);
        enemyListDiv.appendChild(row);
    });
}

document.getElementById('btn-add-player-unit')?.addEventListener('click', () => {
    editingPlayerRoster.push({ jobKey: '劍士' });
    renderRosterUI();
});

document.getElementById('btn-add-enemy-unit')?.addEventListener('click', () => {
    editingEnemyRoster.push({ enemyId: 'enemy_swordsman_base' });
    renderRosterUI();
});

function updateMapSelectDropdown() {
    selectMapBind.innerHTML = '';
    const maps = LevelManager.getSavedMaps();
    maps.forEach(m => {
        const opt = document.createElement('option');
        opt.value = m.mapId;
        opt.textContent = `${m.name} (${m.mapId})`;
        if (m.mapId === currentEditingMapId) opt.selected = true;
        selectMapBind.appendChild(opt);
    });
}

// ==========================================
// 4. UI 路由與選單切換
// ==========================================
document.getElementById('btn-open-editor')?.addEventListener('click', () => {
    currentMode = 'LEVEL_EDITOR';
    mainMenu.style.display = 'none';
    levelEditorPanel.style.display = 'flex';
    mapEditorPanel.style.display = 'none';
    gamePanel.style.display = 'none';
    selectedUnit = null;
    updateMapSelectDropdown();
    renderRosterUI();
    renderGame();
});

document.getElementById('btn-edit-map')?.addEventListener('click', () => {
    currentEditingMapId = selectMapBind.value || 'map_tutorial';
    const mapData = LevelManager.getMap(currentEditingMapId);
    if (mapData) {
        currentEditingMapName = mapData.name;
        mapRadius = mapData.radius;
        LevelManager.applyMapToGrid(mapData, grid);
    }
    if (editingMapNameSpan) editingMapNameSpan.textContent = currentEditingMapId;

    currentMode = 'MAP_EDITOR';
    levelEditorPanel.style.display = 'none';
    mapEditorPanel.style.display = 'flex';
    renderGame();
});

document.getElementById('btn-back-level-editor')?.addEventListener('click', () => {
    LevelManager.saveMap(currentEditingMapId, currentEditingMapName, mapRadius, grid);
    currentMode = 'LEVEL_EDITOR';
    mapEditorPanel.style.display = 'none';
    levelEditorPanel.style.display = 'flex';
    updateMapSelectDropdown();
    renderGame();
});

document.querySelectorAll('#btn-level-back-menu, #btn-game-back').forEach(btn => {
    btn.addEventListener('click', () => {
        currentMode = 'MENU';
        mainMenu.style.display = 'flex';
        levelEditorPanel.style.display = 'none';
        mapEditorPanel.style.display = 'none';
        gamePanel.style.display = 'none';
        selectedUnit = null;
        renderGame();
    });
});

// ==========================================
// 5. 遊戲啟動與戰鬥初始化 (資料驅動 Roster 與出生點)
// ==========================================
function buildLevelFromUI(): LevelData | null {
    const mapId = selectMapBind.value;
    if (!mapId) return null;

    const levelNameInput = document.getElementById('input-level-name') as HTMLInputElement;
    const winCondSelect = document.getElementById('select-win-cond') as HTMLSelectElement;
    const loseCondSelect = document.getElementById('select-lose-cond') as HTMLSelectElement;

    return {
        levelId: `level_${Date.now()}`,
        name: levelNameInput?.value || '未命名關卡',
        mapId,
        winCondition: winCondSelect?.value || 'ANNIHILATION',
        loseCondition: loseCondSelect?.value || 'PLAYER_DEATH',
        playerRoster: [...editingPlayerRoster],
        enemyRoster: editingEnemyRoster.map(e => ({ enemyId: e.enemyId }))
    };
}

document.getElementById('btn-start-game')?.addEventListener('click', () => {
    const levels = LevelManager.getSavedLevels();
    if (levels.length === 0) {
        alert('目前沒有已儲存的關卡！請先進入「關卡編輯器」建立並儲存關卡。');
        return;
    }
    startGameMode(levels[0]);
});

document.getElementById('btn-test-level')?.addEventListener('click', () => {
    const level = buildLevelFromUI();
    if (!level) {
        alert('請先在「綁定地圖」下拉選單中選擇一張地圖！');
        return;
    }
    LevelManager.saveLevel(level);
    startGameMode(level);
});

function startGameMode(level: LevelData) {
    currentMode = 'GAME';
    mainMenu.style.display = 'none';
    levelEditorPanel.style.display = 'none';
    mapEditorPanel.style.display = 'none';
    gamePanel.style.display = 'flex';

    const mapData = LevelManager.getMap(level.mapId);
    if (!mapData) {
        alert(`找不到關卡綁定的地圖：${level.mapId}`);
        return;
    }
    LevelManager.applyMapToGrid(mapData, grid);

    gameManager.units = [];

    // 1. 根據地圖上的 'PLAYER' 出生點與 playerRoster 生成我方單位
    const playerSpawnNodes = grid.getNodes().filter(n => n.spawnPoint === 'PLAYER');
    const allWalkableNodes = grid.getNodes().filter(n => n.isWalkable);

    level.playerRoster.forEach((rosterItem, index) => {
        const node = playerSpawnNodes[index] || playerSpawnNodes[0] || allWalkableNodes[index] || grid.getNode(0, 0, 0);
        if (!node) return;
        const job = JOB_DATA[rosterItem.jobKey] || JOB_DATA['劍士'];
        const unit = new Unit(`P${index + 1}`, node, job, 'PLAYER', 10);
        gameManager.addUnit(unit);
    });

    // 2. 根據地圖上的 'ENEMY' 出生點與 enemyRoster 生成敵方單位
    const enemySpawnNodes = grid.getNodes().filter(n => n.spawnPoint === 'ENEMY');
    const enemyFallbackNodes = allWalkableNodes.filter(n => !gameManager.units.some(u => u.node.equals(n)));

    level.enemyRoster.forEach((rosterItem, index) => {
        const node = enemySpawnNodes[index] || enemySpawnNodes[0] || enemyFallbackNodes[index] || allWalkableNodes[0];
        if (!node) return;
        const enemy = EnemyRegistry.createEnemyUnit(rosterItem.enemyId, node, `E${index + 1}`);
        gameManager.addUnit(enemy);
    });

    selectedUnit = null;
    selectedSkill = null;
    actionMode = 'MOVE';
    gameManager.startGame();
    renderGame();
    console.log(`🎮 啟動關卡 [${level.name}] (綁定地圖: ${level.mapId})`);
}

// ==========================================
// 6. 地圖編輯器互動筆刷
// ==========================================
document.querySelectorAll('#brush-group .brush-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
        document.querySelectorAll('#map-editor-panel .brush-btn').forEach(b => b.classList.remove('active'));
        const target = e.currentTarget as HTMLElement;
        target.classList.add('active');
        activeBrushType = 'TERRAIN';
        activeTerrain = target.getAttribute('data-terrain') as TerrainType;
    });
});

document.querySelectorAll('#spawn-brush-group .brush-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
        document.querySelectorAll('#map-editor-panel .brush-btn').forEach(b => b.classList.remove('active'));
        const target = e.currentTarget as HTMLElement;
        target.classList.add('active');
        activeBrushType = 'SPAWN';
        activeSpawn = target.getAttribute('data-spawn') as any;
    });
});

document.getElementById('btn-export')?.addEventListener('click', () => {
    LevelManager.exportCurrentMapAsJSON(currentEditingMapId, currentEditingMapName, mapRadius, grid);
});

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
// 7. 戰鬥操作與平滑移動動畫
// ==========================================
// 平滑移動動畫函數：讓單位沿著 path 逐格前進
function animateUnitMovement(unit: Unit, path: HexNode[], onComplete: () => void) {
    if (path.length === 0) {
        onComplete();
        return;
    }

    let stepIndex = 0;
    
    function nextStep() {
        if (stepIndex >= path.length) {
            onComplete();
            return;
        }
        unit.node = path[stepIndex];
        stepIndex++;
        renderGame();
        setTimeout(nextStep, 120);
    }

    nextStep();
}

canvas.addEventListener('mousemove', (event) => {
    if (currentMode !== 'GAME' || gameManager.state === GameState.GAME_OVER) return;
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

    if (currentMode === 'MAP_EDITOR') {
        if (activeBrushType === 'TERRAIN') {
            clickedNode.terrain = activeTerrain;
            clickedNode.isWalkable = (activeTerrain !== 'MOUNTAIN' && activeTerrain !== 'WATER');
        } else if (activeBrushType === 'SPAWN') {
            if (activeSpawn === 'CLEAR' || activeSpawn === null) {
                clickedNode.spawnPoint = null;
            } else {
                clickedNode.spawnPoint = activeSpawn;
            }
        }
        renderGame();
        return;
    }

    if (currentMode === 'GAME') {
        if (gameManager.state === GameState.GAME_OVER) return;
        if (gameManager.state !== GameState.PLAYER_PHASE && gameManager.state !== GameState.UNIT_SELECTED) return;

        const clickedUnit = gameManager.units.find(u => u.node.equals(clickedNode));

        if (clickedUnit && clickedUnit.faction === 'PLAYER' && !clickedUnit.hasActed && actionMode === 'MOVE') {
            selectedUnit = clickedUnit;
            gameManager.changeState(GameState.UNIT_SELECTED);
            actionMode = 'MOVE';
            updateRanges();
            renderGame();
            return;
        }

        if (!selectedUnit) return;

        if (clickedNode.equals(selectedUnit.node) && actionMode === 'MOVE') {
            actionMode = 'ATTACK';
            updateRanges();
            renderGame();
            return;
        }

        if (actionMode === 'MOVE') {
            const isReachable = reachableNodes.some(r => r.equals(clickedNode));
            if (isReachable && clickedNode.isWalkable && !clickedUnit) {
                const movePath = Pathfinder.findPath(grid, selectedUnit.node, clickedNode, selectedUnit.job.maxMovement);
                currentPath = [];
                
                // 執行平滑移動動畫
                animateUnitMovement(selectedUnit, movePath, () => {
                    selectedUnit!.hasActed = true;
                    selectedUnit = null;
                    actionMode = 'MOVE';
                    updateRanges();
                    gameManager.checkPlayerTurnEnd();
                    renderGame();
                });
            } else {
                selectedUnit = null;
                updateRanges();
                gameManager.changeState(GameState.PLAYER_PHASE);
            }
        } else if (actionMode === 'ATTACK') {
            const isAttackable = attackableNodes.some(a => a.equals(clickedNode));
            
            if (isAttackable && clickedUnit && clickedUnit.faction === 'ENEMY') {
                let baseDamage = 4;
                let finalDamage = baseDamage;

                if (selectedSkill) {
                    if (selectedUnit.useMp(selectedSkill.mpCost)) {
                        finalDamage = Math.round(baseDamage * selectedSkill.damageMultiplier);
                    }
                }

                const isDead = clickedUnit.takeDamage(finalDamage);
                renderer.addFloatingText(clickedUnit.node, `-${finalDamage}`, '#ff1744');
                
                if (isDead) {
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

// 啟動 60 FPS 迴圈
function gameLoop() {
    renderGame();
    requestAnimationFrame(gameLoop);
}
gameLoop();

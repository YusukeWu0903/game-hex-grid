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
import { PlayerPartyManager } from './data/PlayerParty';
import { PlayerProfileManager } from './core/PlayerProfile';
import type { LevelData } from './data/GameSchema';
import { AudioManager } from './core/AudioManager';
import { JuiceEffects } from './core/JuiceEffects';
import gsap from 'gsap';

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

let currentMode: 'MENU' | 'LEVEL_EDITOR' | 'MAP_EDITOR' | 'DEPLOYMENT' | 'BATTLE' | 'RESULT' = 'MENU';

const mainMenu = document.getElementById('main-menu') as HTMLElement;
const levelEditorPanel = document.getElementById('level-editor-panel') as HTMLElement;
const mapEditorPanel = document.getElementById('map-editor-panel') as HTMLElement;
const gamePanel = document.getElementById('game-panel') as HTMLElement;
const deploymentPanel = document.getElementById('deployment-panel') as HTMLElement;
const resultPanel = document.getElementById('result-panel') as HTMLElement;
const editingMapNameSpan = document.getElementById('editing-map-name') as HTMLElement;
const selectMapBind = document.getElementById('select-map-bind') as HTMLSelectElement;
const currentMapFilenameSpan = document.getElementById('current-map-filename') as HTMLElement;

function updateMapFilenameDisplay() {
    if (currentMapFilenameSpan) {
        const mapId = selectMapBind?.value || currentEditingMapId || 'map_default';
        currentMapFilenameSpan.textContent = `${mapId}.json`;
    }
}

selectMapBind?.addEventListener('change', () => {
    currentEditingMapId = selectMapBind.value;
    updateMapFilenameDisplay();
});

let activeBrushType: 'TERRAIN' | 'SPAWN' = 'TERRAIN';
let activeTerrain: TerrainType = 'PLAIN';
let activeSpawn: 'PLAYER' | 'ENEMY' | 'CLEAR' | null = null;

// 隊伍資料由 PlayerPartyManager 管理，關卡編輯器僅選擇出戰成員
let selectedPartyIndices: number[] = []; // 選中的隊伍單位索引
let editingEnemyRoster: { enemyId: string }[] = [
    { enemyId: 'enemy_swordsman_base' },
    { enemyId: 'enemy_archer_base' },
    { enemyId: 'enemy_heavy_guard' }
];

// 佈署階段：玩家已放置的單位 (node -> unit)
const deployedUnits: Map<string, Unit> = new Map();

// 當前關卡資料
let currentLevelData: LevelData | null = null;

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

    if (currentMode !== 'BATTLE' || !selectedUnit || selectedUnit.hasActed) return;

    if (actionMode === 'MOVE') {
            const occupiedNodes = currentMode === 'BATTLE' && gameManager.units
                ? gameManager.units.filter(u => u !== selectedUnit).map(u => u.node)
                : [];
            reachableNodes = Pathfinder.getReachableNodes(grid, selectedUnit.node, selectedUnit.job.maxMovement, occupiedNodes);
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
    } else if (currentMode === 'DEPLOYMENT') {
        // 佈署階段：顯示地圖、出生點、已佈署單位、可用單位清單
        renderer.render(grid, [], [], Array.from(deployedUnits.values()), []);
    } else if (currentMode === 'BATTLE') {
        // Debug: 單位清單快照 (每回合印一次)
        const prevCount = (window as any).__lastUnitCount;
        const currentCount = gameManager.units.length;
        if (prevCount !== currentCount) {
            console.log(`📊 [Debug Render] 單位數量變更: ${prevCount ?? '?'} -> ${currentCount}`,
                gameManager.units.map(u => `${u.id}(HP:${u.hp}/${u.maxHp}, Faction:${u.faction})`).join(', ')
            );
            (window as any).__lastUnitCount = currentCount;
        }

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
    } else if (currentMode === 'RESULT') {
        renderer.render(grid, [], [], gameManager.units, []);
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

gameManager.onUnitDamaged = (unit, damage) => {
    renderer.addFloatingText(unit.node, `-${damage}`, '#ff1744');
    AudioManager.playHit();
    JuiceEffects.shakeCanvas(canvas);
    renderGame();
};

gameManager.onGameOver = (isVictory) => {
    currentMode = 'RESULT';
    gamePanel.style.display = 'none';
    resultPanel.style.display = 'flex';

    if (isVictory) {
        AudioManager.playVictory();
    }

    const resultTitle = document.getElementById('result-title');
    const resultMessage = document.getElementById('result-message');

    if (resultTitle) {
        resultTitle.textContent = isVictory ? '🎉 戰鬥勝利 (VICTORY)' : '💀 戰鬥失敗 (DEFEAT)';
        resultTitle.style.color = isVictory ? '#38bdf8' : '#f87171';
    }

    if (resultMessage) {
        if (isVictory) {
            resultMessage.innerHTML = `
                <div style="color: #38bdf8; font-weight: bold; margin-bottom: 8px;">恭喜獲勝！</div>
                <div>成功擊退所有敵軍。</div>
                <div style="color: #64748b; font-size: 11px; margin-top: 8px;">我方單位狀態已同步至全域隊伍表 (Roster)。</div>
            `;
        } else {
            resultMessage.innerHTML = `
                <div style="color: #f87171; font-weight: bold; margin-bottom: 8px;">戰鬥失敗</div>
                <div>我方部隊全軍覆沒...</div>
                <div style="color: #64748b; font-size: 11px; margin-top: 8px;">請返回主選單重新整裝。</div>
            `;
        }
    }

    // 同步玩家單位狀態至全域 PlayerProfile
    gameManager.units.forEach(unit => {
        if (unit.faction === 'PLAYER') {
            PlayerProfileManager.syncUnitToProfile(unit);
        }
    });

    renderGame();
};

// ==========================================
// 佈署階段相關邏輯
// ==========================================
function renderDeploymentUnitList() {
    const listDiv = document.getElementById('deployment-unit-list');
    if (!listDiv) return;

    const profile = PlayerProfileManager.getProfile();
    // 過濾出未佈署且 HP > 0 的單位（陣亡單位不可佈署）
    const availableUnits = profile.roster.filter(member => 
        member.currentHp > 0 &&
        !Array.from(deployedUnits.values()).some(u => u.id === member.unitId)
    );

    // 列出已被過濾掉的陣亡單位數量（供除錯參考）
    const deadUnits = profile.roster.filter(m => m.currentHp <= 0);
    if (deadUnits.length > 0) {
        console.warn(`⚠️ [Deployment] 過濾掉 ${deadUnits.length} 個 HP ≤ 0 的陣亡單位:`, deadUnits.map(d => `${d.customName || d.jobKey}(HP:${d.currentHp})`));
    }

    if (availableUnits.length === 0) {
        listDiv.innerHTML = '<div style="color: #64748b; font-size: 11px; text-align: center; padding: 8px;">所有單位已佈署完畢</div>' +
            (deadUnits.length > 0 ? '<div style="color: #f87171; font-size: 10px; text-align: center; padding: 4px; margin-top: 4px;">⚠️ 有 ' + deadUnits.length + ' 個陣亡單位無法出戰</div>' : '');
        return;
    }

    listDiv.innerHTML = '';
    availableUnits.forEach((member) => {
        const isSelected = selectedUnitForDeployment?.unitId === member.unitId;
        const row = document.createElement('div');
        row.className = 'roster-item';
        row.style.display = 'flex';
        row.style.alignItems = 'center';
        row.style.gap = '6px';
        row.style.padding = '8px';
        row.style.background = isSelected ? '#0369a1' : '#1e293b';
        row.style.borderRadius = '6px';
        row.style.border = `1px solid ${isSelected ? '#38bdf8' : '#334155'}`;
        row.style.cursor = 'pointer';

        const infoSpan = document.createElement('span');
        infoSpan.style.flex = '1';
        infoSpan.style.fontSize = '11px';
        infoSpan.style.color = '#cbd5e1';
        infoSpan.style.pointerEvents = 'none';
        infoSpan.textContent = `${member.customName || member.jobKey} (Lv.${member.level} ${member.jobKey})`;

        const statsSpan = document.createElement('span');
        statsSpan.style.fontSize = '10px';
        statsSpan.style.color = '#64748b';
        statsSpan.style.pointerEvents = 'none';
        statsSpan.textContent = `HP:${member.currentHp}/${member.maxHp} MP:${member.currentMp}/${member.maxMp}`;

        row.appendChild(infoSpan);
        row.appendChild(statsSpan);

        row.addEventListener('click', () => {
            selectedUnitForDeployment = member;
            console.log('🎯 已選中待佈署單位:', member);
            renderDeploymentUnitList();
        });

        listDiv.appendChild(row);
    });
}

let selectedUnitForDeployment: any = null; // 待佈署的單位資料

function clearDeploymentSelection() {
    selectedUnitForDeployment = null;
    const listDiv = document.getElementById('deployment-unit-list');
    if (listDiv) {
        listDiv.querySelectorAll('.roster-item').forEach((item: Element) => {
            (item as HTMLElement).style.borderColor = '#334155';
        });
    }
}

// ==========================================
// 3. 關卡編輯器 Roster UI 綁定
// ==========================================
function renderRosterUI() {
    const playerListDiv = document.getElementById('player-roster-list');
    const enemyListDiv = document.getElementById('enemy-roster-list');
    if (!playerListDiv || !enemyListDiv) return;

    // 我方出戰名單：僅顯示已勾選的單位，並提供下拉選單可切換職業、刪除鈕移除
    playerListDiv.innerHTML = '';
    const party = PlayerPartyManager.getParty();
    
    if (selectedPartyIndices.length === 0) {
        playerListDiv.innerHTML = '<div style="color: #64748b; font-size: 11px; text-align: center; padding: 8px;">尚未選擇出戰單位，請點擊上方按鈕選擇</div>';
    } else {
        selectedPartyIndices.forEach((partyIndex) => {
            const member = party[partyIndex];
            if (!member) return;
            
            const row = document.createElement('div');
            row.className = 'roster-item';
            row.style.alignItems = 'center';
            row.style.gap = '6px';

            // 職業下拉選單（允許在出戰名單中臨時切換職業）
            const select = document.createElement('select');
            Object.keys(JOB_DATA).forEach(jobKey => {
                const opt = document.createElement('option');
                opt.value = jobKey;
                opt.textContent = jobKey;
                if (jobKey === member.jobKey) opt.selected = true;
                select.appendChild(opt);
            });
            select.addEventListener('change', (e) => {
                const newJobKey = (e.target as HTMLSelectElement).value;
                // 更新 PartyManager 中的資料
                PlayerPartyManager.updateUnit(member.unitId, { jobKey: newJobKey });
                renderRosterUI();
            });

            const infoSpan = document.createElement('span');
            infoSpan.style.flex = '1';
            infoSpan.style.fontSize = '11px';
            infoSpan.style.color = '#cbd5e1';
            infoSpan.textContent = `${member.customName || member.jobKey} (Lv.${member.level} ${member.jobKey})`;

            const statsSpan = document.createElement('span');
            statsSpan.style.fontSize = '10px';
            statsSpan.style.color = '#64748b';
            statsSpan.textContent = `HP:${member.currentHp}/${member.maxHp} MP:${member.currentMp}/${member.maxMp}`;

            const delBtn = document.createElement('button');
            delBtn.className = 'roster-del-btn';
            delBtn.textContent = '移除';
            delBtn.style.fontSize = '10px';
            delBtn.style.padding = '2px 6px';
            delBtn.addEventListener('click', () => {
                // 從出戰名單移除（不刪除隊伍資料）
                selectedPartyIndices = selectedPartyIndices.filter(i => i !== partyIndex);
                renderRosterUI();
            });

            row.appendChild(select);
            row.appendChild(infoSpan);
            row.appendChild(statsSpan);
            row.appendChild(delBtn);
            playerListDiv.appendChild(row);
        });
    }

    // 敵方 Roster：維持原本可編輯敵人種類
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
    updateMapFilenameDisplay();
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
    
    // 重置編輯器狀態：清空選中的地圖、出戰名單、敵方名單
    currentEditingMapId = '';
    currentEditingMapName = '';
    mapRadius = 4;
    selectedPartyIndices = [];
    editingEnemyRoster = [
        { enemyId: 'enemy_swordsman_base' },
        { enemyId: 'enemy_archer_base' },
        { enemyId: 'enemy_heavy_guard' }
    ];
    
    // 重置地圖為乾淨狀態
    grid.generateHexagonMap(mapRadius);
    
    updateMapSelectDropdown();
    renderRosterUI();
    renderGame();
});

document.getElementById('btn-edit-map')?.addEventListener('click', () => {
    currentEditingMapId = selectMapBind.value || '';
    if (!currentEditingMapId) {
        alert('請先在「綁定地圖」下拉選單中選擇一張地圖！');
        return;
    }
    const mapData = LevelManager.getMap(currentEditingMapId);
    if (mapData) {
        currentEditingMapName = mapData.name;
        mapRadius = mapData.radius;
        LevelManager.applyMapToGrid(mapData, grid);
    } else {
        // 如果找不到地圖，建立新的乾淨地圖
        mapRadius = 4;
        grid.generateHexagonMap(mapRadius);
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

document.getElementById('btn-reset-map')?.addEventListener('click', () => {
    // 重置編輯：盤面全部清空重新編輯
    mapRadius = 4;
    grid.generateHexagonMap(mapRadius);
    currentEditingMapName = currentEditingMapId; // 保持地圖 ID 不變
    renderGame();
    console.log('🔄 地圖編輯器已重置為乾淨狀態');
});

document.getElementById('btn-cancel-map')?.addEventListener('click', () => {
    // 返回不儲存：恢復上一次儲存的版本
    const mapData = LevelManager.getMap(currentEditingMapId);
    if (mapData) {
        LevelManager.applyMapToGrid(mapData, grid);
    } else {
        // 如果沒有儲存過的版本，給一個乾淨地圖
        mapRadius = 4;
        grid.generateHexagonMap(mapRadius);
    }
    currentMode = 'LEVEL_EDITOR';
    mapEditorPanel.style.display = 'none';
    levelEditorPanel.style.display = 'flex';
    updateMapSelectDropdown();
    renderGame();
    console.log('↩️ 已取消編輯，恢復上一次儲存版本');
});

document.querySelectorAll('#btn-level-back-menu, #btn-game-back').forEach(btn => {
    btn.addEventListener('click', () => {
        currentMode = 'MENU';
        mainMenu.style.display = 'flex';
        levelEditorPanel.style.display = 'none';
        mapEditorPanel.style.display = 'none';
        gamePanel.style.display = 'none';
        deploymentPanel.style.display = 'none';
        resultPanel.style.display = 'none';
        selectedUnit = null;
        renderGame();
    });
});

// 佈署階段按鈕事件
document.getElementById('btn-deployment-cancel')?.addEventListener('click', () => {
    // 返回關卡編輯器
    currentMode = 'LEVEL_EDITOR';
    deploymentPanel.style.display = 'none';
    levelEditorPanel.style.display = 'flex';
    deployedUnits.clear();
    clearDeploymentSelection();
    renderGame();
});

document.getElementById('btn-start-battle')?.addEventListener('click', () => {
    // 確認出戰，開始戰鬥
    if (deployedUnits.size === 0) {
        alert('請至少佈署一名單位！');
        return;
    }
    startBattleMode();
});

document.getElementById('btn-result-back-menu')?.addEventListener('click', () => {
    // 結算後返回主選單
    currentMode = 'MENU';
    resultPanel.style.display = 'none';
    mainMenu.style.display = 'flex';
    gameManager.units = [];
    deployedUnits.clear();
    renderGame();
});

document.getElementById('btn-game-back')?.addEventListener('click', () => {
    // 戰鬥中放棄返回主選單
    currentMode = 'MENU';
    mainMenu.style.display = 'flex';
    gamePanel.style.display = 'none';
    gameManager.units = [];
    deployedUnits.clear();
    selectedUnit = null;
    renderGame();
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

    // 依據勾選的隊伍索引產出 playerRoster
    const party = PlayerPartyManager.getParty();
    const playerRoster = selectedPartyIndices.map(idx => party[idx]).filter(Boolean).map(m => ({
        jobKey: m.jobKey,
        name: m.customName
    }));

    return {
        levelId: `level_${Date.now()}`,
        name: levelNameInput?.value || '未命名關卡',
        mapId,
        winCondition: winCondSelect?.value || 'ANNIHILATION',
        loseCondition: loseCondSelect?.value || 'PLAYER_DEATH',
        playerRoster,
        enemyRoster: editingEnemyRoster.map(e => ({ enemyId: e.enemyId }))
    };
}

document.getElementById('btn-start-game')?.addEventListener('click', () => {
    let levels = LevelManager.getSavedLevels();
    if (levels.length === 0) {
        // 自動建立一個預設關卡（使用 map_custom 地圖 + 我方隊伍 + 預設敵方陣容）
        const party = PlayerPartyManager.getParty();
        const defaultLevel: LevelData = {
            levelId: `level_auto_${Date.now()}`,
            name: '自動戰役',
            mapId: 'map_custom',
            winCondition: 'ANNIHILATION',
            loseCondition: 'PLAYER_DEATH',
            playerRoster: party.map(u => ({ jobKey: u.jobKey, name: u.customName })),
            enemyRoster: [
                { enemyId: 'enemy_swordsman_base' },
                { enemyId: 'enemy_archer_base' },
                { enemyId: 'enemy_heavy_guard' }
            ]
        };
        LevelManager.saveLevel(defaultLevel);
        levels = LevelManager.getSavedLevels();
        console.log(`📦 [自動戰役] 已建立預設關卡，使用地圖: ${defaultLevel.mapId}`);
    }
    startDeploymentMode(levels[0]);
});

document.getElementById('btn-test-level')?.addEventListener('click', () => {
    const level = buildLevelFromUI();
    if (!level) {
        alert('請先在「綁定地圖」下拉選單中選擇一張地圖！');
        return;
    }
    LevelManager.saveLevel(level);
    startDeploymentMode(level);
});

function startDeploymentMode(level: LevelData) {
    currentMode = 'DEPLOYMENT';
    mainMenu.style.display = 'none';
    levelEditorPanel.style.display = 'none';
    mapEditorPanel.style.display = 'none';
    gamePanel.style.display = 'none';
    deploymentPanel.style.display = 'flex';

    const mapData = LevelManager.getMap(level.mapId);
    if (!mapData) {
        alert(`找不到關卡綁定的地圖：${level.mapId}`);
        return;
    }
    LevelManager.applyMapToGrid(mapData, grid);

    // 清空佈署狀態
    deployedUnits.clear();
    clearDeploymentSelection();
    selectedUnit = null;
    selectedSkill = null;
    actionMode = 'MOVE';

    // 存儲當前關卡資料供後續使用
        currentLevelData = level;

        // 戰前恢復：將全域隊伍表中所有單位血量補滿至 maxHp
        const profile = PlayerProfileManager.getProfile();
        profile.roster.forEach(member => {
            if (member.currentHp < member.maxHp || member.currentMp < member.maxMp) {
                const oldHp = member.currentHp;
                const oldMp = member.currentMp;
                member.currentHp = member.maxHp;
                member.currentMp = member.maxMp;
                console.log(`💖 [戰前恢復] ${member.customName || member.jobKey}: HP ${oldHp}/${member.maxHp} → ${member.currentHp}/${member.maxHp}, MP ${oldMp}/${member.maxMp} → ${member.currentMp}/${member.maxMp}`);
            }
        });
        // 持久化
        localStorage.setItem('TACTICS_PLAYER_PROFILE', JSON.stringify(profile));

        // 新增：在初始化完成時渲染一次單位清單 UI
        renderDeploymentUnitList();

    renderGame();
    console.log(`📋 進入佈署階段 [${level.name}]`);
}

    // 開始戰鬥模式：將佈署好的單位轉入戰鬥，生成敵方
    function startBattleMode() {
        currentMode = 'BATTLE';
        deploymentPanel.style.display = 'none';
        gamePanel.style.display = 'flex';

        if (!currentLevelData) return;

        // 將佈署好的單位加入戰鬥
        gameManager.units = [];
        deployedUnits.forEach(unit => {
            gameManager.addUnit(unit);
        });

        // 根據關卡資料生成敵方單位
        const enemySpawnNodes = grid.getNodes().filter(n => n.spawnPoint === 'ENEMY');
        const allWalkableNodes = grid.getNodes().filter(n => n.isWalkable);
        const enemyFallbackNodes = allWalkableNodes.filter(n => !gameManager.units.some(u => u.node.equals(n)));

        currentLevelData.enemyRoster.forEach((rosterItem, index) => {
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
        console.log(`🎮 啟動戰鬥 [${currentLevelData.name}]`);
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
// 平滑移動動畫：使用 GSAP 進行逐格像素補間，取代 setTimeout 逐格跳動
function animateUnitMovement(unit: Unit, path: HexNode[], onComplete: () => void) {
    if (path.length === 0) {
        onComplete();
        return;
    }

    // 1. 計算每格的像素座標
    const pixelPath = path.map(node => renderer.getPixelCoords(node));

    // 2. 從起始位置開始（若 unit 已有視覺偏移則沿用，否則從起點開始）
    const startPixel = renderer.getPixelCoords(unit.node);
    unit.visualX = startPixel.px;
    unit.visualY = startPixel.py;

    // 3. 建立 GSAP 時間軸，逐格平滑補間
    const tl = gsap.timeline({
        onComplete: () => {
            // 動畫結束：設定最終 node、清除視覺偏移
            unit.node = path[path.length - 1];
            unit.visualX = undefined;
            unit.visualY = undefined;
            renderGame();
            onComplete();
        }
    });

        // 4. 逐格加入補間
        const stepDuration = 0.12; // 每格 120ms，與原 setTimeout 一致

        pixelPath.forEach((target) => {
            tl.to(unit, {
                visualX: target.px,
                visualY: target.py,
                duration: stepDuration,
                ease: 'power1.out',
                onStart: () => {
                    AudioManager.playMove();
                },
                onUpdate: () => {
                    renderGame();
                }
            });
        });
    }

    canvas.addEventListener('mousemove', (event) => {
    if (currentMode !== 'BATTLE' || gameManager.state === GameState.GAME_OVER) return;
    if (gameManager.state !== GameState.PLAYER_PHASE && gameManager.state !== GameState.UNIT_SELECTED) return;
    if (!selectedUnit || selectedUnit.hasActed) return;

    const rect = canvas.getBoundingClientRect();
    const cubeCoords = renderer.pixelToHex(event.clientX - rect.left, event.clientY - rect.top);
    const targetNode = grid.getNode(cubeCoords.x, cubeCoords.y, cubeCoords.z);

    currentPath = [];
        if (targetNode && !targetNode.equals(selectedUnit.node) && actionMode === 'MOVE') {
            const occupiedNodes = gameManager.units
                .filter(u => u !== selectedUnit)
                .map(u => u.node);
            currentPath = Pathfinder.findPath(grid, selectedUnit.node, targetNode, selectedUnit.job.maxMovement, occupiedNodes);
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

        if (currentMode === 'DEPLOYMENT') {
            // 佈署階段：點擊 'P' 出生點放置選中的單位
            if (clickedNode.spawnPoint === 'PLAYER') {
                if (!selectedUnitForDeployment) {
                    alert('請先從左側未佈署單位清單中點擊選擇要佈署的單位！');
                    return;
                }
                
                // 檢查該格子是否已有單位
                const existingUnit = Array.from(deployedUnits.values()).find(u => u.node.equals(clickedNode));
                if (existingUnit) {
                    deployedUnits.delete(existingUnit.id);
                }
            
                // 建立單位實體並放置
                const unit = PlayerProfileManager.createUnitFromData(selectedUnitForDeployment, clickedNode);
                deployedUnits.set(unit.id, unit);
            
                clearDeploymentSelection();
                renderDeploymentUnitList();
                renderGame();
                console.log(`📍 佈署單位：${unit.id} 於 ${clickedNode.toString()}`);
            } else {
                const clickedUnit = Array.from(deployedUnits.values()).find(u => u.node.equals(clickedNode));
                if (clickedUnit) {
                    deployedUnits.delete(clickedUnit.id);
                    renderDeploymentUnitList();
                    renderGame();
                    console.log(`↩️ 收回已佈署單位：${clickedUnit.id}`);
                } else {
                    alert('請點擊標記為 🚩「我方」的出生點格子來佈署單位！');
                }
            }
            return;
        }

        if (currentMode === 'BATTLE') {
        if (gameManager.state === GameState.GAME_OVER) return;
        if (gameManager.state !== GameState.PLAYER_PHASE && gameManager.state !== GameState.UNIT_SELECTED) return;

        const clickedUnit = gameManager.units.find(u => u.node.equals(clickedNode));

        if (clickedUnit && clickedUnit.faction === 'PLAYER' && !clickedUnit.hasActed && actionMode === 'MOVE') {
                    selectedUnit = clickedUnit;
                    console.log(`🎯 [Debug] 選取單位: ${clickedUnit.id} (HP:${clickedUnit.hp}/${clickedUnit.maxHp}, Node:${clickedUnit.node.toString()})`);
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
                        const occupiedNodes = gameManager.units
                            .filter(u => u !== selectedUnit)
                            .map(u => u.node);
                        const movePath = Pathfinder.findPath(grid, selectedUnit.node, clickedNode, selectedUnit.job.maxMovement, occupiedNodes);
                currentPath = [];
                
                // 執行平滑移動動畫
                animateUnitMovement(selectedUnit, movePath, () => {
                    actionMode = 'ATTACK'; // 移動完切換為攻擊模式
                    updateRanges();        // 重新計算攻擊範圍 (紅色格子)
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
                // 1. 攻擊敵人
                let baseDamage = 4;
                let finalDamage = baseDamage;

                if (selectedSkill) {
                    if (selectedUnit.useMp(selectedSkill.mpCost)) {
                        finalDamage = Math.round(baseDamage * selectedSkill.damageMultiplier);
                    }
                }

                const isDead = clickedUnit.takeDamage(finalDamage);
                                // 透過 onUnitDamaged 回呼統一觸發飄字、音效、震動（與敵方攻擊我方時效果一致）
                                if (gameManager.onUnitDamaged) {
                                    gameManager.onUnitDamaged(clickedUnit, finalDamage);
                                } else {
                                    renderer.addFloatingText(clickedUnit.node, `-${finalDamage}`, '#ff1744');
                                }
                                console.log(`⚔️ [Debug] 玩家 ${selectedUnit.id} 攻擊 ${clickedUnit.id} 造成 ${finalDamage} 傷害 (HP:${clickedUnit.hp}/${clickedUnit.maxHp}${isDead ? ' 💀' : ''})`);
                
                if (isDead) {
                    console.warn(`⚠️ [Debug Unit Death] 單位 ${clickedUnit.id} 血量歸零！座標: ${clickedUnit.node.toString()}`, new Error().stack);
                    gameManager.units = gameManager.units.filter(u => u !== clickedUnit);
                    console.log(`🗑️ [Debug] 已從陣列移除死亡單位 ${clickedUnit.id}，剩餘 ${gameManager.units.length} 個`);
                }

                // 攻擊完畢：標記行動結束，重置選取狀態
                selectedUnit.hasActed = true;
                selectedUnit = null;
                selectedSkill = null;
                actionMode = 'MOVE';
                updateRanges();
                gameManager.checkPlayerTurnEnd();
            } else {
                // 2. 只要已移動並進入 ATTACK 模式，點擊自己或點擊無效區域（空地/友軍），皆一律視為「待機」並結束行動！
                selectedUnit.hasActed = true;
                selectedUnit = null;
                selectedSkill = null;
                actionMode = 'MOVE';
                updateRanges();
                gameManager.checkPlayerTurnEnd();
            }
        }

        renderGame();
    }
});

window.addEventListener('keydown', (event) => {
    if (currentMode !== 'BATTLE' || !selectedUnit || actionMode !== 'ATTACK') return;

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

// ==========================================
// 我方單位選擇彈出視窗邏輯
// ==========================================
const unitSelectModal = document.getElementById('unit-select-modal') as HTMLElement;
const unitSelectList = document.getElementById('unit-select-list') as HTMLElement;
const btnSelectPlayerUnits = document.getElementById('btn-select-player-units') as HTMLButtonElement;
const btnCloseUnitModal = document.getElementById('btn-close-unit-modal') as HTMLButtonElement;
const btnConfirmUnitSelect = document.getElementById('btn-confirm-unit-select') as HTMLButtonElement;

function openUnitSelectModal() {
    renderUnitSelectList();
    unitSelectModal.style.display = 'flex';
}

function closeUnitSelectModal() {
    unitSelectModal.style.display = 'none';
}

function renderUnitSelectList() {
    if (!unitSelectList) return;
    const party = PlayerPartyManager.getParty();
    
    if (party.length === 0) {
        unitSelectList.innerHTML = '<div style="color: #94a3b8; text-align: center; padding: 20px;">隊伍中尚無任何單位</div>';
        return;
    }

    unitSelectList.innerHTML = '';
    party.forEach((member, index) => {
        const isSelected = selectedPartyIndices.includes(index);
        const item = document.createElement('div');
        item.className = `modal-unit-item ${isSelected ? 'selected' : ''}`;
        
        const checkbox = document.createElement('input');
        checkbox.type = 'checkbox';
        checkbox.checked = isSelected;
        
        const infoDiv = document.createElement('div');
        infoDiv.className = 'modal-unit-info';
        
        const nameDiv = document.createElement('div');
        nameDiv.className = 'modal-unit-name';
        nameDiv.textContent = `${member.customName || member.jobKey}`;
        
        const detailDiv = document.createElement('div');
        detailDiv.className = 'modal-unit-detail';
        detailDiv.textContent = `Lv.${member.level} ${member.jobKey}`;
        
        const statsDiv = document.createElement('div');
        statsDiv.className = 'modal-unit-stats';
        statsDiv.textContent = `HP ${member.currentHp}/${member.maxHp}  MP ${member.currentMp}/${member.maxMp}`;
        
        infoDiv.appendChild(nameDiv);
        infoDiv.appendChild(detailDiv);
        infoDiv.appendChild(statsDiv);
        
        item.appendChild(checkbox);
        item.appendChild(infoDiv);
        
        item.addEventListener('click', (e) => {
            // 防止點擊 checkbox 時觸發兩次
            if (e.target !== checkbox) {
                checkbox.checked = !checkbox.checked;
            }
            const newChecked = checkbox.checked;
            if (newChecked) {
                if (!selectedPartyIndices.includes(index)) selectedPartyIndices.push(index);
            } else {
                selectedPartyIndices = selectedPartyIndices.filter(i => i !== index);
            }
            item.classList.toggle('selected', newChecked);
        });
        
        checkbox.addEventListener('click', (e) => {
            e.stopPropagation();
            const newChecked = checkbox.checked;
            if (newChecked) {
                if (!selectedPartyIndices.includes(index)) selectedPartyIndices.push(index);
            } else {
                selectedPartyIndices = selectedPartyIndices.filter(i => i !== index);
            }
            item.classList.toggle('selected', newChecked);
        });
        
        unitSelectList.appendChild(item);
    });
}

btnSelectPlayerUnits?.addEventListener('click', openUnitSelectModal);
btnCloseUnitModal?.addEventListener('click', closeUnitSelectModal);
btnConfirmUnitSelect?.addEventListener('click', () => {
    renderRosterUI(); // 更新主面板顯示
    closeUnitSelectModal();
});

// 點擊遮罩關閉
unitSelectModal?.addEventListener('click', (e) => {
    if (e.target === unitSelectModal) closeUnitSelectModal();
});

// ==========================================
// 8. UI 點擊音效：全域監聽所有按鈕與選單按鈕
// ==========================================
document.querySelectorAll('#main-menu button, .floating-panel button, .modal-content button').forEach(btn => {
    btn.addEventListener('click', () => {
        AudioManager.playClick();
    });
});

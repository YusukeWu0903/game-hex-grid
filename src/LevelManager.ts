// src/LevelManager.ts
import { HexGrid } from './HexGrid';
import type { MapData, LevelData } from './data/GameSchema';

export class LevelManager {
    private static MAP_REGISTRY_KEY = 'TACTICS_MAP_REGISTRY';
    private static LEVEL_REGISTRY_KEY = 'TACTICS_LEVEL_REGISTRY';

    public static getDefaultTestLevel(): { map: MapData, level: LevelData } {
        const map: MapData = {
            mapId: 'map_tutorial',
            name: '新手演練場',
            radius: 4,
            terrains: {
                "1,0,-1": "FOREST",
                "-1,0,1": "FOREST",
                "0,2,-2": "MOUNTAIN"
            },
            spawnPoints: {
                "0,0,0": "PLAYER",
                "-1,0,1": "PLAYER",
                "2,-1,-1": "ENEMY"
            }
        };

        const level: LevelData = {
            levelId: 'level_01',
            name: '關卡 1：遭遇戰',
            mapId: 'map_tutorial',
            winCondition: 'ANNIHILATION',
            loseCondition: 'PLAYER_DEATH',
            enemyRoster: [
                { enemyId: 'enemy_swordsman_base', x: 2, y: -1, z: -1 },
                { enemyId: 'enemy_archer_base', x: 1, y: -2, z: 1 }
            ]
        };

        return { map, level };
    }

    // 地圖存取
    public static saveMap(mapId: string, name: string, radius: number, grid: HexGrid): MapData {
        const terrains: Record<string, any> = {};
        const spawnPoints: Record<string, any> = {};

        grid.getNodes().forEach(n => {
            const key = `${n.x},${n.y},${n.z}`;
            if (n.terrain !== 'PLAIN') {
                terrains[key] = n.terrain;
            }
            if (n.spawnPoint) {
                spawnPoints[key] = n.spawnPoint;
            }
        });

        const mapData: MapData = { mapId, name, radius, terrains, spawnPoints };
        const maps = this.getSavedMaps();
        const index = maps.findIndex(m => m.mapId === mapId);
        if (index >= 0) {
            maps[index] = mapData;
        } else {
            maps.push(mapData);
        }
        localStorage.setItem(this.MAP_REGISTRY_KEY, JSON.stringify(maps));
        return mapData;
    }

    public static getSavedMaps(): MapData[] {
        const data = localStorage.getItem(this.MAP_REGISTRY_KEY);
        if (!data) {
            const { map } = this.getDefaultTestLevel();
            return [map];
        }
        try {
            return JSON.parse(data);
        } catch (e) {
            const { map } = this.getDefaultTestLevel();
            return [map];
        }
    }

    public static getMap(mapId: string): MapData | undefined {
        const maps = this.getSavedMaps();
        return maps.find(m => m.mapId === mapId);
    }

    // 關卡存取
    public static saveLevel(level: LevelData): void {
        const levels = this.getSavedLevels();
        const index = levels.findIndex(l => l.levelId === level.levelId);
        if (index >= 0) {
            levels[index] = level;
        } else {
            levels.push(level);
        }
        localStorage.setItem(this.LEVEL_REGISTRY_KEY, JSON.stringify(levels));
    }

    public static getSavedLevels(): LevelData[] {
        const data = localStorage.getItem(this.LEVEL_REGISTRY_KEY);
        if (!data) {
            const { level } = this.getDefaultTestLevel();
            return [level];
        }
        try {
            return JSON.parse(data);
        } catch (e) {
            const { level } = this.getDefaultTestLevel();
            return [level];
        }
    }

    public static applyMapToGrid(map: MapData, grid: HexGrid): void {
        grid.generateHexagonMap(map.radius);
        
        // 清空舊的 terrain 與 spawnPoint
        grid.getNodes().forEach(node => {
            node.terrain = 'PLAIN';
            node.isWalkable = true;
            node.spawnPoint = null;
        });

        // 套用地形
        for (const [key, terrain] of Object.entries(map.terrains)) {
            const [x, y, z] = key.split(',').map(Number);
            const node = grid.getNode(x, y, z);
            if (node) {
                node.terrain = terrain;
                node.isWalkable = (terrain !== 'MOUNTAIN' && terrain !== 'WATER');
            }
        }

        // 套用出生點
        for (const [key, faction] of Object.entries(map.spawnPoints)) {
            const [x, y, z] = key.split(',').map(Number);
            const node = grid.getNode(x, y, z);
            if (node) {
                node.spawnPoint = faction;
            }
        }
    }

    public static exportCurrentMapAsJSON(mapId: string, name: string, radius: number, grid: HexGrid): void {
        const mapData = this.saveMap(mapId, name, radius, grid);
        const jsonStr = JSON.stringify(mapData, null, 2);
        const blob = new Blob([jsonStr], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `${mapId}.json`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
        console.log(`📤 地圖 [${name}] 匯出成功！`);
    }

    public static importMapFromJSON(jsonData: string): MapData | null {
        try {
            const mapData: MapData = JSON.parse(jsonData);
            if (!mapData.mapId || !mapData.terrains) {
                throw new Error('Invalid MapData JSON');
            }
            const maps = this.getSavedMaps();
            const index = maps.findIndex(m => m.mapId === mapData.mapId);
            if (index >= 0) {
                maps[index] = mapData;
            } else {
                maps.push(mapData);
            }
            localStorage.setItem(this.MAP_REGISTRY_KEY, JSON.stringify(maps));
            return mapData;
        } catch (e) {
            console.error('Failed to import map JSON', e);
            alert('匯入失敗：地圖 JSON 格式錯誤');
            return null;
        }
    }
}

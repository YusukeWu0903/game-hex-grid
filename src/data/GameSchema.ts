// src/data/GameSchema.ts
import type { TerrainType } from '../HexNode';
import type { Faction } from '../entities/Unit';

export interface MapData {
    mapId: string;
    name: string;
    radius: number;
    terrains: Record<string, TerrainType>;       // Key: "x,y,z", Value: TerrainType
    spawnPoints: Record<string, Faction>;        // Key: "x,y,z", Value: 'PLAYER' | 'ENEMY' | 'NEUTRAL'
}

export interface EnemyTemplate {
    enemyId: string;
    name: string;
    jobKey: string;     // 對應 JOB_DATA 的 key，如 '劍士' 或 '弓箭手'
    baseHp: number;
    baseMp: number;
    aiType: string;     // 如 'AGGRESSIVE'
}

export interface LevelData {
    levelId: string;
    name: string;
    mapId: string;
    winCondition: string;
    loseCondition: string;
    playerRoster: {
        jobKey: string;
        name?: string;
    }[];
    enemyRoster: {
        enemyId: string;
        x?: number;
        y?: number;
        z?: number;
    }[];
}

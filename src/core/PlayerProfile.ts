// src/core/PlayerProfile.ts
import { Unit } from '../entities/Unit';
import { HexNode } from '../HexNode';
import { JOB_DATA } from '../entities/Job';

export interface PartyUnitData {
    unitId: string;
    jobKey: string;
    customName?: string;
    level: number;
    currentHp: number;
    maxHp: number;
    currentMp: number;
    maxMp: number;
    exp: number;
}

export interface PlayerProfile {
    roster: PartyUnitData[];
    unlockedLevels: string[];
    currentLevelIndex: number;
}

const PROFILE_STORAGE_KEY = 'TACTICS_PLAYER_PROFILE';

export class PlayerProfileManager {
    private static profile: PlayerProfile | null = null;

    public static initialize(): PlayerProfile {
        const saved = this.load();
        if (saved) {
            this.profile = saved;
            return this.profile;
        }

        return this.createMockProfile();
    }

    public static createMockProfile(): PlayerProfile {
        const roster: PartyUnitData[] = [
            {
                unitId: 'player_swordsman_01',
                jobKey: '劍士',
                customName: '艾爾',
                level: 3,
                currentHp: 12,
                maxHp: 12,
                currentMp: 4,
                maxMp: 4,
                exp: 120
            },
            {
                unitId: 'player_swordsman_02',
                jobKey: '劍士',
                customName: '羅伊',
                level: 2,
                currentHp: 11,
                maxHp: 11,
                currentMp: 4,
                maxMp: 4,
                exp: 60
            },
            {
                unitId: 'player_archer_01',
                jobKey: '弓箭手',
                customName: '琳恩',
                level: 2,
                currentHp: 10,
                maxHp: 10,
                currentMp: 4,
                maxMp: 4,
                exp: 80
            }
        ];

        this.profile = {
            roster,
            unlockedLevels: ['level_01'],
            currentLevelIndex: 0
        };
        this.save();
        return this.profile;
    }

    public static getProfile(): PlayerProfile {
        if (!this.profile) return this.initialize();
        return this.profile;
    }

    public static getRoster(): PartyUnitData[] {
        return this.getProfile().roster;
    }

    public static addUnitToRoster(unitData: PartyUnitData): void {
        const profile = this.getProfile();
        profile.roster.push(unitData);
        this.save();
    }

    public static removeUnitFromRoster(unitId: string): void {
        const profile = this.getProfile();
        profile.roster = profile.roster.filter(u => u.unitId !== unitId);
        this.save();
    }

    public static updateUnitInRoster(unitId: string, updates: Partial<PartyUnitData>): void {
        const profile = this.getProfile();
        const idx = profile.roster.findIndex(u => u.unitId === unitId);
        if (idx >= 0) {
            profile.roster[idx] = { ...profile.roster[idx], ...updates };
            this.save();
        }
    }

    // 根據 PartyUnitData 建立 Unit 實體
    public static createUnitFromData(data: PartyUnitData, node: HexNode): Unit {
        const job = JOB_DATA[data.jobKey] || JOB_DATA['劍士'];
        const unit = new Unit(data.unitId, node, job, 'PLAYER', data.maxHp);
        unit.hp = data.currentHp;
        unit.maxMp = data.maxMp;
        unit.mp = data.currentMp;
        return unit;
    }

    // 將 Unit 狀態同步回 Profile
    public static syncUnitToProfile(unit: Unit): void {
        this.updateUnitInRoster(unit.id, {
            currentHp: unit.hp,
            maxHp: unit.maxHp,
            currentMp: unit.mp,
            maxMp: unit.maxMp
        });
    }

    public static unlockLevel(levelId: string): void {
        const profile = this.getProfile();
        if (!profile.unlockedLevels.includes(levelId)) {
            profile.unlockedLevels.push(levelId);
            this.save();
        }
    }

    public static setCurrentLevel(levelId: string): void {
        const profile = this.getProfile();
        const idx = profile.unlockedLevels.indexOf(levelId);
        if (idx >= 0) {
            profile.currentLevelIndex = idx;
            this.save();
        }
    }

    private static load(): PlayerProfile | null {
        const data = localStorage.getItem(PROFILE_STORAGE_KEY);
        if (!data) return null;
        try {
            return JSON.parse(data);
        } catch {
            return null;
        }
    }

    private static save(): void {
        if (this.profile) {
            localStorage.setItem(PROFILE_STORAGE_KEY, JSON.stringify(this.profile));
        }
    }
}

// 啟動時自動初始化
PlayerProfileManager.initialize();
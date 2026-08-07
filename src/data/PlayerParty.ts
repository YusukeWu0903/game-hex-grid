// src/data/PlayerParty.ts
import { Unit } from '../entities/Unit';
import { HexNode } from '../HexNode';
import { JOB_DATA } from '../entities/Job';
import type { LevelData } from './GameSchema';

export interface PartyUnitData {
    unitId: string;        // 唯一 ID
    jobKey: string;        // 職業 key
    customName?: string;   // 自訂名稱
    level: number;         // 等級
    currentHp: number;     // 當前 HP
    maxHp: number;         // 最大 HP
    currentMp: number;     // 當前 MP
    maxMp: number;         // 最大 MP
    exp: number;           // 經驗值
    // 未來可擴充：裝備、技能、屬性點數等
}

const PARTY_STORAGE_KEY = 'TACTICS_PLAYER_PARTY';

export class PlayerPartyManager {
    private static party: PartyUnitData[] = [];

    // 初始化預設隊伍 (若無資料)
    public static initialize(): PartyUnitData[] {
        const saved = this.load();
        if (saved.length > 0) {
            this.party = saved;
            return this.party;
        }

        // 預設隊伍：劍士、法師、弓箭手 各一隻
        this.party = [
            {
                unitId: 'party_swordsman_01',
                jobKey: '劍士',
                customName: '劍士艾爾',
                level: 1,
                currentHp: 10,
                maxHp: 10,
                currentMp: 4,
                maxMp: 4,
                exp: 0
            },
            {
                unitId: 'party_mage_01',
                jobKey: '法師',
                customName: '法師露娜',
                level: 1,
                currentHp: 8,
                maxHp: 8,
                currentMp: 12,
                maxMp: 12,
                exp: 0
            },
            {
                unitId: 'party_archer_01',
                jobKey: '弓箭手',
                customName: '弓手凱爾',
                level: 1,
                currentHp: 9,
                maxHp: 9,
                currentMp: 4,
                maxMp: 4,
                exp: 0
            }
        ];
        this.save();
        return this.party;
    }

    public static getParty(): PartyUnitData[] {
        if (this.party.length === 0) return this.initialize();
        return this.party;
    }

    public static addUnit(unitData: PartyUnitData): void {
        this.party.push(unitData);
        this.save();
    }

    public static removeUnit(unitId: string): void {
        this.party = this.party.filter(u => u.unitId !== unitId);
        this.save();
    }

    public static updateUnit(unitId: string, updates: Partial<PartyUnitData>): void {
        const idx = this.party.findIndex(u => u.unitId === unitId);
        if (idx >= 0) {
            this.party[idx] = { ...this.party[idx], ...updates };
            this.save();
        }
    }

    // 根據 Party 資料建立 Unit 實體
    public static createUnitFromPartyData(data: PartyUnitData, node: HexNode): Unit {
        const job = JOB_DATA[data.jobKey] || JOB_DATA['劍士'];
        const unit = new Unit(data.unitId, node, job, 'PLAYER', data.maxHp);
        unit.hp = data.currentHp;
        unit.maxMp = data.maxMp;
        unit.mp = data.currentMp;
        // 未來可擴充：unit.level = data.level; unit.exp = data.exp; 等
        return unit;
    }

    // 將 Unit 狀態同步回 Party
    public static syncUnitToParty(unit: Unit): void {
        this.updateUnit(unit.id, {
            currentHp: unit.hp,
            maxHp: unit.maxHp,
            currentMp: unit.mp,
            maxMp: unit.maxMp
        });
    }

    private static load(): PartyUnitData[] {
        const data = localStorage.getItem(PARTY_STORAGE_KEY);
        if (!data) return [];
        try {
            return JSON.parse(data);
        } catch {
            return [];
        }
    }

    private static save(): void {
        localStorage.setItem(PARTY_STORAGE_KEY, JSON.stringify(this.party));
    }

    // 匯出成 LevelData 所需的 playerRoster 格式
    public static exportToLevelRoster(): LevelData['playerRoster'] {
        return this.party.map(u => ({
            jobKey: u.jobKey,
            name: u.customName
        }));
    }
}

// 啟動時自動初始化
PlayerPartyManager.initialize();
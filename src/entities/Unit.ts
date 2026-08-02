// src/entities/Unit.ts
import { HexNode } from '../HexNode'; // 請確認引入路徑符合你的專案結構
import type { JobStats } from './Job';

export type Faction = 'PLAYER' | 'ENEMY' | 'NEUTRAL'; // 陣營

export class Unit {
    public id: string;
    public node: HexNode;     // 單位目前所在的格子
    public job: JobStats;     // 單位的職業
    public faction: Faction;  // 屬於我方還是敵方
    public hasActed: boolean = false; // 本回合是否已行動完畢
    public hp: number;
    public maxMp: number; // 新增
    public mp: number;    // 新增
    public maxHp: number;

    constructor(id: string, node: HexNode, job: JobStats, faction: Faction, maxHp: number = 10) {
        this.id = id;
        this.node = node;
        this.job = job;
        this.faction = faction;
        this.maxHp = maxHp;
        this.hp = maxHp;
        this.maxMp = job.maxMp; // 初始化 MP
        this.mp = job.maxMp;
    }

    // 新增：消耗 MP 方法
    public useMp(cost: number): boolean {
        if (this.mp >= cost) {
            this.mp -= cost;
            return true;
        }
        return false;
    }

    // 回合開始時重置狀態
    public resetAction() {
        this.hasActed = false;
    }

    // 新增：承受傷害方法
    public takeDamage(amount: number): boolean {
        this.hp -= amount;
        if (this.hp <= 0) {
            this.hp = 0;
            return true; // 代表已死亡
        }
        return false;
    }
}
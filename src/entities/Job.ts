// src/entities/Job.ts

export interface Skill {
    id: string;
    name: string;
    mpCost: number;
    rangeMin: number;
    rangeMax: number;
    damageMultiplier: number; // 傷害倍率 (例如 1.5 代表 150% 傷害)
    isAoE: boolean;           // 是否為範圍傷害
}

export interface Job {
    name: string;
    maxMovement: number;
    attackRangeMin: number;
    attackRangeMax: number;
    maxMp: number;           // 新增：最大 MP
    skills: Skill[];         // 新增：技能列表
}

export const JOB_DATA: Record<string, Job> = {
    '劍士': {
        name: '劍士',
        maxMovement: 3,
        attackRangeMin: 1,
        attackRangeMax: 1,
        maxMp: 20,
        skills: [
            {
                id: 'HEAVY_SLASH',
                name: '重擊',
                mpCost: 10,
                rangeMin: 1,
                rangeMax: 1,
                damageMultiplier: 1.8,
                isAoE: false
            }
        ]
    },
    '弓箭手': {
        name: '弓箭手',
        maxMovement: 2,
        attackRangeMin: 2,
        attackRangeMax: 3,
        maxMp: 30,
        skills: [
            {
                id: 'POWER_SHOT',
                name: '強力射擊',
                mpCost: 15,
                rangeMin: 2,
                rangeMax: 4,
                damageMultiplier: 1.5,
                isAoE: false
            }
        ]
    }
};
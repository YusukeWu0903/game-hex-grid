// src/data/EnemyRegistry.ts
import { Unit } from '../entities/Unit';
import { HexNode } from '../HexNode';
import { JOB_DATA } from '../entities/Job';
import type { EnemyTemplate } from './GameSchema';

export class EnemyRegistry {
    public static ENEMY_TEMPLATES: Record<string, EnemyTemplate> = {
        'enemy_swordsman_base': {
            enemyId: 'enemy_swordsman_base',
            name: '帝國步兵',
            jobKey: '劍士',
            baseHp: 12,
            baseMp: 4,
            aiType: 'AGGRESSIVE'
        },
        'enemy_archer_base': {
            enemyId: 'enemy_archer_base',
            name: '帝國弓手',
            jobKey: '弓箭手',
            baseHp: 10,
            baseMp: 4,
            aiType: 'CAUTIOUS'
        },
        'enemy_heavy_guard': {
            enemyId: 'enemy_heavy_guard',
            name: '帝國重裝兵',
            jobKey: '劍士',
            baseHp: 18,
            baseMp: 2,
            aiType: 'DEFENSIVE'
        },
        'enemy_assassin': {
            enemyId: 'enemy_assassin',
            name: '帝國刺客',
            jobKey: '劍士',
            baseHp: 8,
            baseMp: 6,
            aiType: 'AGGRESSIVE'
        },
        'enemy_mage': {
            enemyId: 'enemy_mage',
            name: '帝國法師',
            jobKey: '法師',
            baseHp: 8,
            baseMp: 12,
            aiType: 'CAUTIOUS'
        }
    };

    public static getAllTemplates(): EnemyTemplate[] {
        return Object.values(this.ENEMY_TEMPLATES);
    }

    public static createEnemyUnit(enemyId: string, node: HexNode, customId?: string): Unit {
        const template = this.ENEMY_TEMPLATES[enemyId] || this.ENEMY_TEMPLATES['enemy_swordsman_base'];
        const job = JOB_DATA[template.jobKey] || JOB_DATA['劍士'];
        const unitId = customId || `Enemy_${Math.floor(Math.random() * 1000)}`;
        return new Unit(unitId, node, job, 'ENEMY', template.baseHp);
    }
}

// src/data/EnemyRegistry.ts
import { Unit } from '../entities/Unit';
import { JOB_DATA } from '../entities/Job';
import type { HexNode } from '../HexNode';
import type { EnemyTemplate } from './GameSchema';

export class EnemyRegistry {
    // 敵人範本註冊表
    private static templates: Record<string, EnemyTemplate> = {
        'enemy_swordsman_base': {
            enemyId: 'enemy_swordsman_base',
            name: '帝國步兵',
            jobKey: '劍士',
            baseHp: 12,
            baseMp: 10,
            aiType: 'AGGRESSIVE'
        },
        'enemy_archer_base': {
            enemyId: 'enemy_archer_base',
            name: '帝國弓手',
            jobKey: '弓箭手',
            baseHp: 8,
            baseMp: 15,
            aiType: 'AGGRESSIVE'
        }
    };

    public static getTemplate(enemyId: string): EnemyTemplate | undefined {
        return this.templates[enemyId];
    }

    public static createEnemyUnit(enemyId: string, node: HexNode, instanceId: string = 'E1'): Unit {
        const template = this.templates[enemyId] || this.templates['enemy_swordsman_base'];
        const job = JOB_DATA[template.jobKey] || JOB_DATA['劍士'];
        
        const unit = new Unit(instanceId, node, job, 'ENEMY', template.baseHp);
        // 若有需要也可設定自訂名稱或 aiType
        return unit;
    }
}

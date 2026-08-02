// src/core/GameState.ts

export enum GameState {
    INIT = "INIT",                     // 遊戲初始化
    TURN_START = "TURN_START",         // 回合開始
    PLAYER_PHASE = "PLAYER_PHASE",     // 玩家行動階段
    UNIT_SELECTED = "UNIT_SELECTED",   // 選中單位
    UNIT_ACTION = "UNIT_ACTION",       // 單位行動中
    ENEMY_PHASE = "ENEMY_PHASE",       // 敵方回合
    NEUTRAL_PHASE = "NEUTRAL_PHASE", // <--- 新增第三方行動階段
    TURN_END = "TURN_END",             // 回合結算
    GAME_OVER = "GAME_OVER"            // 遊戲結束 (勝負已分)
}
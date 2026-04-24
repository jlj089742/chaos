# Chaos 项目逻辑梳理与卡牌扩展说明

## 1. 项目整体逻辑（当前实现）

### 1.1 场景主流程
- `mainPage.tscn`：主菜单入口。
- `roleSelect.tscn`：角色选择与开局存档初始化。
- `gameMain.tscn`（`scripts/game_main.gd`）：大地图主循环。
  - 读取存档与配置（年份事件、起始事件、普通事件、商店、宝箱、战斗等）。
  - 在地图上生成交互点（`start / event / box / rest / battle / boss`）。
  - 承接事件、商店、战斗、战利品、年份推进。
- 其它展示页：
  - `cardLibrary.tscn`：图鉴（按职业看卡牌）。
  - `deckLibrary.tscn`：牌库（看玩家当前拥有卡牌）。

### 1.2 数据来源
- `config/*.json` 为配置驱动：
  - `wizard_info.json` / `monster_info.json`：卡牌数据。
  - `year_event.json` / `event_repo.json` / `start_repo.json` / `box_repo.json` / `shop_list.json`：地图与事件内容。
- `scripts/*_config.gd` 负责加载并返回配置对象数组。

### 1.3 卡牌相关运行链路
- 初始牌库：`game_main.gd::_ensure_player_deck_initialized()` 根据角色补齐。
- 地图牌库弹层：`game_main.gd::_refresh_deck_overlay()`。
- 商店购买卡牌：`game_main.gd::_apply_shop_item_effect()`。
- 战斗掉落卡牌：`game_main.gd::_open_loot_card_pick()` -> 选择后写回 `player_deck`。
- 图鉴页：`card_library_page.gd` 按职业展示卡牌池。
- 牌库页：`deck_library_page.gd` 按 `player_deck` 的 card_id 展示卡牌。

---

## 2. 本次重构目标与原则

目标：在**不改变现有逻辑与行为**前提下，提升卡牌代码可拓展性。

原则：
- 不改动卡牌业务规则（掉落规则、购买规则、初始化规则保持不变）。
- 抽离重复代码，统一卡牌数据访问和卡牌 UI 构建入口。
- 让后续新增职业/卡池/卡牌样式时只改少量集中模块。

---

## 3. 本次代码结构优化（已完成）

### 3.1 新增统一卡牌 UI 工厂
- 文件：`scripts/card_ui_factory.gd`
- 类：`CardUIFactory`
- 作用：
  - 统一创建卡牌 UI：`create_card_widget(card, scale, ignore_mouse)`。
  - 统一卡牌底图、锚点、费用文字、名称、描述布局规则。
  - 提供基础贴图尺寸：`get_base_texture_size()`，供网格布局计算。

结果：图鉴页、牌库页、地图内牌库弹层、商店、战利品都复用同一套卡牌渲染逻辑。

### 3.2 新增统一卡牌目录服务
- 文件：`scripts/card_catalog.gd`
- 类：`CardCatalog`
- 作用：
  - 按职业加载卡牌：`load_cards_by_role(role)`。
  - 构建 card_id -> card_def 映射：`build_card_map(include_wizard, include_monster)`。
  - 生成职业可选卡池 id 列表（含 reward 过滤）：`build_card_pool_ids_for_role(role, reward_one_only)`。

结果：卡牌来源与筛选规则集中，减少多处重复循环与重复判定。

### 3.3 页面与主流程接入统一能力
- `scripts/card_library_page.gd`
  - 使用 `CardCatalog.load_cards_by_role()` 获取数据。
  - 使用 `CardUIFactory.create_card_widget()` 渲染卡牌。
- `scripts/deck_library_page.gd`
  - 使用 `CardCatalog.build_card_map()` 映射牌库卡牌。
  - 使用 `CardUIFactory.get_base_texture_size()` 计算网格间距。
  - 使用 `CardUIFactory.create_card_widget()` 渲染。
- `scripts/game_main.gd`
  - `create_card_for_ui()` 委托到 `CardUIFactory`。
  - 掉落、商店、牌库弹层等所有卡牌渲染改为统一工厂。
  - 卡牌映射与选池逻辑改为 `CardCatalog`。
  - 删除本文件中重复的卡牌 UI 构建代码与重复卡池构建代码。

---

## 4. 当前可扩展点（推荐扩展方式）

### 4.1 新增职业卡牌来源
1. 在 `CardCatalog.load_cards_by_role()` 添加新职业分支。
2. 若职业卡牌在新配置文件中，新增对应 `*_config.gd` 加载器。
3. 图鉴页和牌库页无需再复制渲染代码，自动复用工厂。

### 4.2 新增卡牌 UI 样式
1. 仅修改 `CardUIFactory.create_card_widget()`。
2. 所有页面与弹层同步生效，避免样式漂移。

### 4.3 调整掉落卡池策略
1. 优先修改 `CardCatalog.build_card_pool_ids_for_role()` 的筛选逻辑。
2. 战利品流程继续调用已有接口，不需要改多个业务入口。

---

## 5. 回归验证建议

- 图鉴页：
  - `Wizard / Beast` 卡牌正常显示。
  - `Master / Sword` 仍显示“敬请期待”。
- 牌库页：
  - 存档有牌时可正确按 id 渲染。
  - 空牌库时提示“暂无牌”。
- 地图内：
  - 顶栏牌库弹层可正常打开与关闭。
  - 商店卡牌商品展示/购买后加入牌库正常。
  - 战斗掉落卡牌三选一与放弃逻辑正常。
- 视觉一致性：
  - 各入口卡牌费用、标题、描述布局一致。

---

## 6. 重构收益总结

- 单一职责更清晰：`CardCatalog` 管数据，`CardUIFactory` 管展示。
- 重复代码明显减少，后续维护点集中。
- 拓展新职业、新卡池、新卡面样式时改动范围可控，回归风险更低。

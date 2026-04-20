# leap-pinyin.nvim

## 项目概述

基于 fork 版 `leap.nvim` 的 LazyVim 插件，扩展中文拼音搜索能力。核心能力：**中英文统一搜索**——用户敲击拉丁字母时，leap 同时匹配英文字面字符和中文字符的拼音编码，共享同一个 label 池，按距离排序分配 label。

支持两种拼音方案（运行时二选一）：
- **全拼首字母模式**：2 键对应连续 2 个汉字的首字母（输入 `zh` 命中 `中华`、`这会` 等）
- **双拼模式（小鹤方案）**：2 键对应 1 个汉字的完整双拼编码（输入 `vs` 命中 `中`）

默认配置为双拼（小鹤）。搜索范围仅限当前 buffer。

## 来源任务

- 主任务: [[T-0074-Leap拼音搜索插件设计]]（`Tasks/tasks/T-0074-Leap拼音搜索插件设计/T-0074-Leap拼音搜索插件设计.md`）

> 开发进度继续在 Tasks 中维护，本项目只负责代码实现。

## 设计文档

- `Tasks/tasks/T-0074-Leap拼音搜索插件设计/design.md` — 完整方案设计，含架构图、数据结构、leap 改造点、字典数据源选型、配置 API、MVP 范围、4 天里程碑、风险与备案
- `Tasks/tasks/T-0074-Leap拼音搜索插件设计/T-0074-Leap拼音搜索插件设计.md` — 任务主文件，含 12 项关键决策记录

## 开发指引

### 技术栈
- **Lua**（运行时）+ **Fennel**（fork 的 leap 原生语言，改造时可能需要读/改 Fennel 源码）
- **Python**（构建期脚本，仅用于生成字典数据，不随插件发布）
- 平台：LazyVim / Neovim 0.9+

### 项目结构（规划）
```
leap-pinyin.nvim/
├── lua/leap-pinyin/
│   ├── init.lua              入口 + setup()
│   ├── pinyin/
│   │   ├── data/
│   │   │   ├── initials.lua  全拼首字母表（构建期生成）
│   │   │   └── shuangpin.lua 双拼编码表（构建期生成）
│   │   ├── matcher.lua       中英混合匹配核心
│   │   └── cache.lua         buffer 级缓存（v0.2 再做）
│   └── leap-hook.lua         注入 leap get-targets 的挂钩
├── fnl/leap/                 fork 自 leap.nvim 的 Fennel 源码
├── scripts/
│   ├── build_dict.py         基于 pinyin-data 生成 Lua 字典
│   └── shuangpin_table.py    小鹤声母韵母映射（构建期）
├── tests/
└── README.md
```

### 核心约定

1. **target 结构扩展**：leap 原生 target 新增 `width` 字段（显示列宽），`source` 字段（`literal` / `pinyin` / `shuangpin`）。变长 target 的处理是双拼模式的关键。

2. **显示列宽天然对齐**：
   - 英文 target：2 个 ASCII 字符 = 2 显示列
   - 双拼 target：1 个 CJK 字符 = 2 显示列
   - label 放置位置统一按 `col + width` 计算，无需特殊处理
   - 仅**字节范围高亮**需要区分 UTF-8 字节数（CJK 1 字符 = 3 字节）

3. **多音字**：全读音展开。`行` → `{xing, hang}` → 全拼首字母 `xh`，双拼 `{xk, hh}` 两组都作为候选。

4. **大小写**：统一忽略，大写/小写行为一致。

5. **label 排序**：纯按光标距离（策略 A），中英 target 同池混合。后续观察干扰情况再调整。

### 字典数据源

**[mozillazg/pinyin-data](https://github.com/mozillazg/pinyin-data)**（MIT 许可）
- 覆盖 ~41700 汉字（Unihan 全表）
- 多音字质量高
- 预期产物体积：全拼首字母版 ~60KB，双拼版 ~100KB
- 构建脚本 `scripts/build_dict.py` 负责生成，不随插件发布

### 小鹤双拼规则（实现必读）

详见 `design.md` §4.3。要点：
- 声母：`zh/ch/sh → v/i/u`，其余单字母直出
- 韵母：按官方表映射到单字母（`ong=s`、`ang=h`、`ing=k` 等）
- 零声母音节：声母位补用韵母首字母（`爱`=`ad`、`安`=`aj` 等）

### 开发里程碑（按 design.md）

| 阶段 | 内容 | 预估 |
|---|---|---|
| M1 | fork leap + 脚手架 + 构建脚本跑通 | 0.5 天 |
| M2 | `matcher.lua` + 纯 Lua 单元测试 | 1 天 |
| M3 | hook 进 leap + 全拼模式联调 | 1 天 |
| M4 | 双拼模式 + 变长 target 改造 | 1 天 |
| M5 | 配置 API + README + 发布 | 0.5 天 |

### 配置 API

```lua
require("leap-pinyin").setup({
  mode = "shuangpin",         -- "pinyin" | "shuangpin"，默认双拼
  shuangpin_scheme = "xiaohe", -- MVP 只支持小鹤
  enabled = true,
})
```

### 风险提示

- **Fennel 改造门槛**：leap 原生 Fennel 源码，需要熟悉基本语法才能改造 target 收集逻辑。备案是降级为 flash.nvim 扩展方案。
- **变长 target 改造**：修改点分散在 leap 多处（高亮、label 放置、safe label 检查），需要仔细测试。
- **双拼必做**：用户默认配置为双拼，**不做 fallback 降级**为全拼。

### MVP 范围外（v0.2 再做）

- telescope / fzf 集成
- 多双拼方案（自然码、微软、紫光）
- 拼音 target 独立高亮样式
- 前缀/全拼精确匹配模式
- 跨 buffer 搜索
- buffer 级拼音缓存（按需）

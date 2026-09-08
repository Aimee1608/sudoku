# 数独练习册

4×4 / 6×6 / 9×9 三种尺寸的数独 iOS app。关卡制做题，本地记录进度，随时可看参考答案。
无广告、无内购、不联网、不收集数据。

亲子和个人都能玩：4×4 给刚认数字的孩子，6×6 过渡，9×9 分入门/简单/中等/困难四档。

## 在 Mac 上跑起来

```bash
brew install xcodegen   # 只需装一次
cd sudoku
xcodegen generate       # 生成 Sudoku.xcodeproj(不进 git,每次改 project.yml 后重跑)
open Sudoku.xcodeproj
```

真机跑/上架前需要在 Xcode 的 Signing & Capabilities 里选自己的开发者 Team。

## 核心逻辑

`Sources/Models` 下全是纯逻辑，不依赖 SwiftUI，可以脱离 Xcode 工程直接编译验证：

```bash
swiftc -O Sources/Models/*.swift scripts/main.swift -o /tmp/sudoku_smoke
/tmp/sudoku_smoke
```

冒烟测试会验几何、求解唯一性、随机完整解合法性、技巧评级，并按各尺寸各难度实际生成一批题。

### 三块，互相独立

**`Solver`** — 位掩码约束传播（唯一候选 + 隐性唯一）+ MRV 回溯。
每格一个 `UInt16` 候选掩码，行/列/宫各维护一个已用数字掩码。
没用 DLX（Dancing Links）：在 81 格这个规模上性能差异肉眼不可见，
而 DLX 的双向十字链表在 Swift 里要么 unsafe 要么退化成索引数组，代码量是位掩码方案的三倍。
`solutions(of:limit:)` 的 `limit` 用来提前收手——验唯一解传 2 就够。

**`Generator`** — 随机完整解 → 中心对称挖洞（每挖一对都验唯一解）→ 交给评级器定档，
不在目标档就丢掉重来。中心对称是主流数独的视觉惯例；`minClues` 卡了提示数下限，
因为挖到理论下限（4×4 能挖到只剩 4 格）是给求解器看的，不是给人做的。

**`HumanSolver`** — 只用人类技巧推，不回溯猜。技巧按难度从易到难排，
每轮从最简单的开始试：唯一候选 → 隐性唯一 → 区块摒除 → 显性数对 → 隐性数对 →
显性三链 → 矩形对角线（X-Wing）。

难度用**最难技巧定档、加权总分在档内排序**——只看最难技巧的话，
「用一次 X-Wing 就解完」和「用五次」都叫困难，体感差很远。

这块代码一份两用：跑完整个盘面就是**难度评级**，只跑一步就是**提示**——
告诉玩家下一格填哪、为什么，用的是哪个技巧。

### 尺寸是参数，不是三套代码

`BoardSize(boxRows:boxCols:)` 一个结构描述全部三种盘：4×4 是 2×2 宫，6×6 是 2×3 宫，
9×9 是 3×3 宫。求解、生成、评级全部按它算，没有任何一处写死 9。

## 目录结构

```
Sources/
  Models/    BoardSize(几何)/ Solver(求解)/ Generator(生成)/ Technique(人类技巧+评级)
  Views/     Theme(15 套主题配色)
  App/       app 入口
scripts/
  main.swift 核心逻辑冒烟测试,不依赖 Xcode 工程
```

## 主题

15 套可切换主题（浅色 8 / 深色 7），换的是整套——底色、卡片、格线、盘面高亮、
数字颜色，连字体形状和圆角都跟着走。全部免费开放。

配色来源：Catppuccin（Latte / Mocha）、Nord、Dracula、Solarized（Light / Dark）、
Tokyo Night、Rosé Pine Dawn，以及取自 [Tailwind](https://tailwindcss.com) 官方色阶的几套蓝色系
和儿童向配色——开源代码配色方案都是为长时间读代码设计的，普遍低饱和，没有给孩子看的亮色。
色值本身不受版权保护。

字体不打包任何文件：数独的视觉主体是数字，iOS 系统字体自带 `.serif`（New York）、
`.rounded`（SF Rounded）、`.monospaced`（SF Mono）三种设计，`Font.system(size:design:)`
一行就能切。中文一律跟随系统苹方。

**彩色数字**是独立配置项，跟主题互相独立，15 套主题都能开：1 永远红、5 永远青，
还不熟悉字形的孩子靠颜色认位置。开了之后题面和填入改用格底小圆点区分。

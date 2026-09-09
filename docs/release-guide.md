# 迭代与发版指南

首次上架那一堆配置**都是一次性的**。下面第三节起才是每次迭代真正要做的事。

---

## 一、一次性配置（首次上架用，之后不用再碰）

| 项目 | 值 / 位置 |
|---|---|
| Bundle ID | `com.aimee.sudoku` |
| App Store 名称 | 彩虹数独 |
| 隐私政策 URL | https://aimee1608.github.io/sudoku/privacy-policy |
| 分类 | 游戏 → 益智解谜游戏 / 家庭游戏 |
| 年龄分级 | 4+（全选"无"） |
| App 隐私 | 不收集数据 |
| 上架文案 | [`app-store-listing.md`](app-store-listing.md) |

隐私政策靠 GitHub Pages 托管：仓库 Settings → Pages → Source 选 `main` 分支 `/docs` 目录。

---

## 二、日常开发闭环

```bash
xcodegen generate      # 改过 project.yml 就必须重跑
xcodebuild -project Sudoku.xcodeproj -scheme Sudoku \
  -destination 'id=<模拟器UDID>' test
```

跑 `xcrun simctl list devices` 拿模拟器 UDID。

核心逻辑（求解器 / 生成器 / 难度评级 / 对局状态）不依赖 SwiftUI，可以不开 Xcode 直接编译跑：

```bash
swiftc -O Sources/Models/*.swift scripts/main.swift -o /tmp/sudoku_tool && /tmp/sudoku_tool
```

**必须带 `-O`**：没有优化的构建里生成器慢一个数量级。含顶层代码的文件必须叫
`main.swift` 并用 `swiftc` 编译，别用 `swift a.swift b.swift` 解释器模式。

重新生成题库（改了生成器或难度口径才需要）：

```bash
/tmp/sudoku_tool bank Sources/Resources/Banks
```

题库用固定 seed，同一份代码重跑得到同一批题。全量约一分钟。

---

## 三、发版流程（每次迭代就这 3 步）

### 1. 升版本号

改 `project.yml`：

```yaml
MARKETING_VERSION: "1.0.1"      # 用户看到的版本号
CURRENT_PROJECT_VERSION: "2"    # build 号，只增不减，不能跟已上传过的重复
```

同步到 Mac 后 `xcodegen generate`。

### 2. 打包 + 上传

```bash
xcodebuild -project Sudoku.xcodeproj -scheme Sudoku \
  -destination 'generic/platform=iOS' -allowProvisioningUpdates \
  -archivePath /tmp/Sudoku.xcarchive archive
```

看到 `** ARCHIVE SUCCEEDED **` 即成功。然后搬到 Organizer 能看到的位置：

```bash
mkdir -p ~/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d) && \
cp -R /tmp/Sudoku.xcarchive ~/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d)/
```

Xcode → `Window` → `Organizer` → 选中这个 archive → **Distribute App** → App Store Connect → Upload。

> Organizer 只扫 `~/Library/Developer/Xcode/Archives`，放 `/tmp` 里它看不见。
>
> **archive 必须在 Mac 图形终端里跑**：SSH 会话拿不到登录钥匙串里的私钥，
> codesign 会报 `errSecInternalComponent`，在自己终端 `unlock-keychain` 也传递不过去。

### 3. App Store Connect

1. 我的 App → 彩虹数独 → 左侧 **「+ 版本或平台」** → 填新版本号
2. **截图**：UI 有明显变化时必须换，否则违反 Guideline 2.3.3。重新生成见下节
3. 填「**本次更新内容**」
4. 选构建版本（上传后要等 10~30 分钟处理完才出现）
5. **添加以供审核** → **提交以供审核**

---

## 四、重新生成上架截图

ASC 的截图槽位会随 app 支持的设备变，**以页面上实际要求的为准**。1.0.0 提交时要了这三套：

| 显示屏 | 模拟器 | 像素 |
|---|---|---|
| iPhone 6.9" | iPhone 17 Pro Max | 1320 × 2868 |
| iPhone 6.5" | iPhone 11 Pro Max（Xcode 里默认没有，要临时建） | 1242 × 2688 |
| iPad 13" | iPad Pro 13-inch (M5) | 2064 × 2752 |

6.5" 的模拟器要现建现删：

```bash
SIM=$(xcrun simctl create 'iPhone65Shot' \
  com.apple.CoreSimulator.SimDeviceType.iPhone-11-Pro-Max \
  com.apple.CoreSimulator.SimRuntime.iOS-26-5)
# 跑完截图后
xcrun simctl delete $SIM
```

6.5" 那档也接受 1284 × 2778（iPhone 12/13/14 Pro Max），两种任选一种。

截图脚本在 `scripts/shots/`（临时 XCUITest，不进 target，用完即弃）。做法是
`XCTAttachment(screenshot:)` 逐屏截 → `xcodebuild ... -resultBundlePath X.xcresult test`
→ `xcrun xcresulttool export attachments` 导出。

截图要有像样的进度数据，靠 `-demoProgress` 启动参数注入（**只在 DEBUG 构建里生效**，
见 `ProgressStore.init`）。Release 包里没有这段代码。

---

## 五、审核要当心的

| Guideline | 现象 | 修法 |
|---|---|---|
| 2.3.7 | 副标题/关键词/宣传文本里出现"无广告""无内购""免费" | 这些算价格表述，会被拒。**只能写在描述里** |
| 2.3.3 | 截图跟实际界面对不上 | UI 改了就要换截图 |
| — | 上传报 `No orientations were specified` | `project.yml` 里 `INFOPLIST_KEY_UISupportedInterfaceOrientations` 必须声明全部四个方向（iPad 多任务强制），已配好别删 |
| 2.1 | 要求补充信息 | 审核备注写清楚"完全离线、无需账号、全部内容已解锁"，模板在 [`app-store-listing.md`](app-store-listing.md) |

重新提交前若「重新提交至 App 审核」按钮是灰的，说明版本没有任何改动，
随便编辑一处（比如补审核备注）存一下就会亮。

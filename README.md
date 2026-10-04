# Uplink 1.5.5 简体中文补丁

把 Steam 版 **Uplink 1.5.5** 变成简体中文版。

**核心做法：使用原版引擎源码重新编译**，不是外部挂载或注入 —— 中文由游戏自身的 FreeType/GLTT 渲染管线绘制，与原版画面风格完全一致。

---

## 一、包含文件

| 文件 | 大小 | SHA256 |
|---|---|---|
| `Uplink.exe` | 1,908,224 B | `0b6db6ccf10d95d1556801f38ed596b43dc8bc3a17b923332667d19d20a30c77` |
| `fonts.dat` | 2,057,394 B | `657a164775a46cbd6f9a04fd766bcc495a8feb841ac09420d362920e0694998a` |

- `Uplink.exe` —— 重新编译的游戏本体，内含：UTF-8 中文渲染、简体中文文本、以及为兼容重编译版而关闭的完整性自检。
- `fonts.dat` —— 中文字体容器，内含 SimHei 子集（6950 字形，覆盖 GB2312 一、二级汉字库 6763 字 + 全部译文用字 + ASCII/全角标点）。

---

## 二、安装

### 方式 A：脚本一键安装（推荐）

```powershell
powershell -ExecutionPolicy Bypass -File install_zh.ps1
```

默认游戏目录是 Steam 的默认安装路径。如果你的游戏装在别处：

```powershell
powershell -ExecutionPolicy Bypass -File install_zh.ps1 -GameDir "D:\Steam\steamapps\common\Uplink"
```

脚本会自动：
1. 把原始 `Uplink.exe`、`fonts.dat` 备份到 `<游戏目录>\_zh_backup\`；
2. 复制中文版文件；
3. 校验安装后文件的 SHA256，不符会报错。

### 方式 B：手动安装

1. 先**备份**游戏目录下的 `Uplink.exe` 和 `fonts.dat`；
2. 用包内的 `Uplink.exe` 和 `fonts.dat` 覆盖同名文件；
3. 启动游戏。

---

## 三、回滚到原版

```powershell
powershell -ExecutionPolicy Bypass -File install_zh.ps1 -Action rollback
```

或手动：把 `_zh_backup\` 里的 `Uplink.exe.orig`、`fonts.dat.orig` 改回原名覆盖即可。

检查当前状态：

```powershell
powershell -ExecutionPolicy Bypass -File install_zh.ps1 -Action verify
```

---

## 四、技术说明（想了解原理的话）

原版 Steam 版存在三道会阻止「重编译版」运行的机制，补丁逐一处理：

| # | 机制 | 位置 | 处理 |
|---|---|---|---|
| 1 | 用 `world.dat`（14,400,792 字节的开发版文件）在偏移 256/576 处做指纹校验，Steam 发行版根本没有该文件 → 报 `Files integrity is not verified.` 后退出 | `globals_defines.h` 的 `VERIFY_UPLINK_LEGIT` | 编译时关闭 |
| 2 | 加载 `UplinkSteamAuth.dll` 校验 exe 自身完整性，并附带正版「代码卡」验证 | `uplink.cpp::Init_Steam()` | 跳过 DLL，并直接置 `askCodeCard = false` |
| 3 | `SIZE_COMPUTERSCREEN_SUBTITLE` 只有 64 字节，中文 UTF-8 每字 3 字节，长副标题会触发断言崩溃 | `computerscreen.h` | 扩到 256 字节 |

**中文渲染**：原引擎 `GLTTBitmapFont::output()` 用 `(unsigned char)*text` **逐字节**取字符，一个汉字的 3 个 UTF-8 字节被当成 3 个独立字符去查字形 → 全部落空 → 显示为方块 `□`。补丁改为按 UTF-8 解码取码点，并让字形表支持 >255 的码点（惰性加载）。

**换行测量**：`wordwraptext()` 原本以「ASCII 平均字宽」为预算单位、中文记 2 单位，但实际中文字宽约为 1.4 倍，导致每行超宽；现改为**逐字符实测字宽**累加，并且绘制时左右各留 10px 内边距（原先文字画在 `x+10` 却按整宽换行，恒定右溢 10px）。

**翻译来源**：走官方本地化管线 `tools/language/translate.pl` + `strings.txt`，目前 **2534 条**（占可翻译条目 76.1%），覆盖界面标签、教程全文、状态消息、邮件、新闻、任务简报、软件与硬件说明等。

**为什么有些地方仍是英文**：Uplink 把**字符串本身当作数据键**使用，例如 `GetComputer("International Social Security Database")`、`GetHardwareUpgrade("CPU ( 20 Ghz )")`、记录库查询 `"Personal Status = Deceased"`、输入框占位 `"Fill this in"`。这类字符串一旦翻译，运行时按名字反查就会失败。因此建立了**禁译清单**（`Get*`/`Find*`/`strcmp`/`GetRandomRecord`/`IsHWInstalled` 的参数、`game/data/` 世界数据表全量、含查询操作符的模板等），这些保持英文以保证游戏正常运行。另有约 1976 条被官方标记为「无需翻译」（代码片段、调试串、正则、路径）。

---

## 五、已知限制

1. **窗口标题栏乱码**：极少数的系统消息框标题（如 `Uplink 错误`）会显示为 `Uplink 閫欬`。原因是这些字符串经 Windows ANSI API 输出，而游戏内部使用 UTF-8 —— 不影响游戏内文字，属已知小瑕疵。
2. **界面宽度**：原界面按英文字符宽度排版，个别超长中文可能贴近边框。
3. 仅覆盖**界面与文本**；游戏内的位图贴图（图标等）未做改动。

---

## 六、许可与免责

Uplink 由 Introversion Software 开发。其开发者许可第 2.4 条规定：未经书面许可，不得以任何格式分发非英语版本。

**本仓库为个人汉化作品，供持有正版 Uplink 的玩家自行使用。** 请自行购买并持有合法的游戏副本；本补丁不含游戏本体，亦不替代任何正版授权。如权利方提出异议，将立即下架。

---

## 七、构建与可复现性

- 编译：Visual Studio 2019 x86（`/MT`），207 个对象，`COMPILE_FAILED=0`
- 本地化管线：`translate.pl` 生成的 206 个 `-trans.cpp`，**字面量序列可 100% 复现**（每次重新生成结果一致）
- 校验脚本：`build/audit_fullzh/` 下含 4 道语义守卫（比较操作数、查找键、缓冲区、保护清单）与占位符审计，全部通过
- 安装器回归：25 项断言全通过（含篡改拒绝、回滚、BOM、所有权保护）

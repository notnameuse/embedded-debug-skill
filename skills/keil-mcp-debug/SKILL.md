---
name: keil-mcp-debug
description: 在任意工作区为 STM32F4 + ST-Link 搭建并运行"AI 源码级在线调试"链路(OpenOCD + arm-none-eabi-gdb + mcp-gdb)的引导式技能。当用户想在某个工作区用 AI 通过 MCP 对真实 STM32 硬件下断点/单步/看变量/读内存/查调用栈, 或需要首次配置环境(探测/安装工具链、注册 MCP、验证能连板)、执行一次真机调试闭环时使用。仅限 Windows + ST-Link + STM32F4(其它系列/OS 未验证)。
---

# keil-mcp-debug —— 引导式在线调试链路搭建与使用

## 0. 定位与边界(先读)
- 本 skill 只做一件事: 把 AI 经 `mcp-gdb` → `arm-none-eabi-gdb` → OpenOCD(:3333) → ST-Link → STM32F4 这条**源码级调试链路**在某个工作区搭起来并用起来。
- **不负责编译/烧录**: 目标工程的 `project.axf` 由 Keil 编译产出、固件由用户在 Keil 手动 F8 烧录。本 skill 只连"已烧好固件的板 + 对应 axf"。
- **仅验证 Windows + ST-Link + STM32F4**。非 F4 的 target 名与 DBGMCU 位不同, 需自改 `config/toolchain.json` 且未验证。
- **不校验"板上固件 == 你加载的 axf"**: 若改了码没重烧/烧错 hex, 断点与变量会静默错位。调试前务必确认二者一致(哈希/构建时间)。
- **每步先说明要做什么、等用户同意再执行**(安装软件/写配置/复位目标)。全为工作区级, 不碰全局。

## 1. 确定包根 `<PKG>` 与 skill 安装
本 skill 目录**自带脚本与配置**（`scripts/` + `config/`）。`<PKG>` = 本 SKILL.md 所在目录（含 `scripts/`、`config/`）的绝对路径。下文所有脚本用 `<PKG>/scripts/xxx.ps1` 绝对路径调用。
> 安装: 把整个 `keil-mcp-debug/skill/keil-mcp-debug/` 目录（连同其 `scripts/`、`config/`）复制到目标工作区的 `.qoder/skills/keil-mcp-debug/`（Qoder 按工作区发现 skill，每工作区一次）。装好后 `<PKG>` 即 `<工作区>/.qoder/skills/keil-mcp-debug`。

## 2. 阶段 A: 首次 setup(仅当该工作区未配好时)
按序执行, 每步征得同意:

1. **探测**: 跑 `powershell -NoProfile -ExecutionPolicy Bypass -File <PKG>/scripts/env-doctor.ps1`
   - 看输出: `[NODE]/[OOCD]/[GDB]/[SCR]` 是否命中(命中即打绝对路径)、`[PROBE]` 是否检测到 ST-Link、端口是否 `[FREE]`。
2. **缺件引导**: 若 `[MISS]`, env-doctor 会打印建议的 winget 命令。把"将执行哪条命令、装到哪"讲清, **经用户同意后**才运行; 装完回到步骤 1 重探。实在装不上 → 让用户提供工具绝对路径, 手动写进 config。
3. **登记**: 探测到路径后跑 `... env-doctor.ps1 -Register` → 生成/更新 `<PKG>/config/toolchain.json`(绝对路径, 正斜杠)。
4. **配 MCP(工作区级)**: 检查该工作区 `.qoder/mcp.json`:
   - 不存在则创建; 存在则用 `ConvertFrom-Json` 读入并**合并**加入 `gdb` 键(已存在 `gdb` 则跳过并提示, 勿覆盖、勿删其它 server), 写前先 `Copy-Item` 备份 `.bak`。要加入的片段:
     ```json
     "gdb": { "command": "npx", "args": ["-y", "mcp-gdb@0.1.3"], "type": "stdio", "startup_timeout_sec": 20 }
     ```
   - 写前把改动念给用户确认。**绝不写全局 `~/.qoder/mcp.json`**。写完提示用户重载 MCP/重启会话。
5. **连通自检**: `debug_start` → 用 `gdb` MCP 工具 `gdb_start`/`gdb_load`/`gdb_command("target remote :3333")`/`gdb_command("monitor reset halt")` 走一遍, 以 `monitor reset halt` 回显的 pc/msp 对上 axf 向量表即 setup 成功(勿用 `info registers` 判读, 比对细节见 §3「调试动作」); 随后 `gdb_terminate` + `debug_stop`(见 §4)。

## 3. 阶段 B: 每次调试
1. **准备 axf 路径**: 读 `<PKG>/config/toolchain.json` 的 `axfPath`; 为空则问用户要目标工程 `project.axf` 绝对路径并写回该文件(下次复用)。
2. **DWARF 门禁(先做、纯离线、不占探针)**: `... <PKG>/scripts/dwarf-check.ps1 -AxfPath <axf>`。
   - exit 0 → 继续; **exit 1 → 直接停止**(此时尚未起 OpenOCD, 无需 teardown), 告诉用户"该 axf 无源码级调试信息, 请在 Keil 开 DebugInformation/BrowseInformation 重编"; exit 2 → 环境缺 gdb/axf, 回阶段 A。
3. **起 OpenOCD**(门禁过了才起): `... <PKG>/scripts/debug_start.ps1`(会复位目标, 先确认机械安全)。若报端口占用, 先 `debug_stop` 或关闭占用者。
4. **建会话**: 调 `gdb_start`(gdbPath=toolchain.gdbExe, workingDir=当前工作区) → 记下返回的 `sessionId` → `gdb_load`(program=axf 绝对路径, 用正斜杠) → `gdb_command("target remote :<gdbPort>")` → `gdb_command("monitor reset halt")`。注意: 这步 reset 会毁掉 attach 已抓到的运行现场; 排查死机/卡住需要保住现场时, 跳过 `monitor reset halt`, 直接从 attach 的停止态读(见 §3「调试动作」)。
5. **调试动作**: 用 `gdb_set_breakpoint`/`gdb_continue`/`gdb_next`/`gdb_step`/`gdb_finish`/`gdb_print`/`gdb_backtrace`/`gdb_examine`/`gdb_info_registers`/`gdb_list_source`。关键约定:
   - `gdb_continue`/`gdb_next` **异步立即返回 `^running`**, 命中/单步结果需**事后**再发一条命令(如 `gdb_command("bt")`/`gdb_print`)才会读到停止态。
   - **`monitor reset` 由 OpenOCD 侧执行, gdb 收不到 `*stopped` 事件**: reset 之后 `gdb_info_registers`/`gdb_backtrace`/`gdb_print`(局部变量) 读到的仍是**复位前的旧值** —— gdb 未更新寄存器/栈帧缓存(实测: OpenOCD 已报新 pc, gdb 仍回报旧值; 再发一次 `monitor halt` 也不刷新); `gdb_print` 全局变量虽走实时内存读, 但目标尚停复位态、RAM 未重新初始化, 拿到的同样是复位前旧值。**别把这类旧值误判成"固件 != axf"或"变量被优化掉"**(与 §0 的一致性提示是两回事)。两条正确读法: ① 只判复位后的位置 → 以 `monitor reset halt` **回显的 pc/msp** 为准(与 axf 的 `__Vectors` 比对时注意: 向量第二字末位是 Thumb 标志, 回显 PC 为其偶数地址, 应按忽略末位比对); ② 要 gdb 侧现场可信 → 先 `gdb_set_breakpoint("<入口或目标函数>")` → `gdb_continue` → **命中之后**再读。
   - **同时硬件断点数 ≤ 6**(Cortex-M4 FPB); 第 7 个 `break` 表层会"成功"但不生效, 超限错误**只在 OpenOCD 日志**。用完 `gdb_command("delete")` 即删。
   - 同一 `sessionId` 的命令**必须串行**, 勿并行。
   - continue 失控兜底: `... <PKG>/scripts/openocd_halt.ps1 -Cmd halt`。
   - 需要 `list` 源码时 `gdb_command("directory <源码根正斜杠>")`。
6. 解读结果回报用户; 需要改码走"改码→(用户)重编译+重烧→回到本阶段(重新过 DWARF 门禁)"。

## 4. 结束必做 teardown(每个调试任务收尾)
按序: `gdb_command("delete")` → `gdb_command("monitor reset halt")`(目标停复位态) → `gdb_terminate` → `... <PKG>/scripts/debug_stop.ps1`(复验端口 `[FREE]`)。
> reset halt + 停 OpenOCD 后 Cortex-M 通常保持 halt(板不跑), 需再复位/上电恢复, 属正常非故障。

## 5. 硬约束
- 编译/烧录/调试共用同一 ST-Link(SWD), **串行不可并发**; 调试前确保 Keil 调试会话已关、无其它 OpenOCD 占用探针。
- 任何"装软件 / 写 mcp.json / 复位目标"动作, 先征得用户同意再执行。
- 首次调试前必过 DWARF 门禁; 固件与 axf 一致性由用户保证(skill 不校验, 需提示风险)。

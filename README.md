# embedded-debug-skill

面向真实嵌入式设备的系统化调试 Skill。让 AI Agent 在 STM32 / ARM Cortex-M + FreeRTOS 项目里按证据定位问题，并跑通从采集现场到板端验证的完整闭环。

A systematic debugging skill for real embedded hardware. It makes your AI agent locate STM32 / ARM Cortex-M + FreeRTOS issues from evidence, and close the loop from field data collection all the way to on-target verification.

[中文说明](#中文说明) ｜ [English](#english)

---

## 中文说明

### 这个 Skill 解决什么问题

嵌入式调试的难点在于信息稀缺。板子死了，没有堆栈；任务卡住了，没有日志；偶发故障复现一次要半小时。多数 AI 助手在这种场景下会退化成猜测：读一遍代码，给出三个可能的原因，让你自己逐个试。

这个 Skill 的作用是约束 Agent 的调试行为。它规定先查什么、根据结果下一步查什么、什么证据才算定位、什么情况下不允许声称问题已解决。核心立场只有一句：

> 证据优先于猜测，真实设备数据优先于静态代码推测。

它同时明确了职责边界。Skill 负责调试策略，Serial Agent / MCP 负责实际连接设备、采集数据、编译、烧录和验证。环境里没有某项能力时，Agent 必须退化为给出需要人工执行的最小操作步骤，禁止假装执行。

### 本仓库包含的 Skill

本仓库平铺了两个互相配合的 Skill：

| Skill | 定位 |
|---|---|
| `embedded-debugging` | 通用嵌入式调试方法论 + Serial Agent/MCP 的编译/烧录/看串口闭环（决策规范，本身不连硬件） |
| `keil-mcp-debug` | STM32F4 + ST-Link 的**源码级在线调试**能力：经 mcp-gdb + arm-none-eabi-gdb + OpenOCD 下断点/单步/看变量/读内存/查调用栈（仅 Windows） |

`embedded-debugging` 在需要断点级源码调试时**委托** `keil-mcp-debug` 执行；**建议两者同时安装**（每个工作区各装一次），只用其一也能独立工作。

### 覆盖范围

- **平台**：STM32F0/F1/F2/F3/F4/F7/G0/G4/H5/H7 等 Cortex-M 系列
- **系统**：FreeRTOS（Task / Queue / Semaphore / Mutex / EventGroup / Software Timer）
- **驱动**：HAL / LL / CMSIS / 裸机外设驱动
- **工具链**：GCC / arm-none-eabi-gcc / ARM Compiler / Keil 工程
- **调试链路**：ST-Link / J-Link / OpenOCD / GDB / SWD / JTAG
- **外设与总线**：UART / I2C / SPI / CAN / USB / ADC / PWM / TIM / DMA
- **故障类型**：HardFault / BusFault / UsageFault / MemManage、栈溢出、堆耗尽、内存越界、死锁、优先级反转、竞态条件、DMA 与 Cache 一致性

### 章节速查表

SKILL.md 共 24 章，按用途分为五类。

**方法论（第 1–6 章）**

| 章节 | 内容 |
|---|---|
| 1. 定位 | Skill 与 Serial Agent 的职责划分 |
| 2. 适用范围 | 支持的平台、系统、工具链、故障类型 |
| 3. 工具与职责边界 | 工具调用七原则，先观察后修改 |
| 4. 标准调试状态机 | INIT → REPRODUCE → COLLECT → HYPOTHESIS → LOCALIZE → PATCH → BUILD → FLASH → VERIFY |
| 5. 分层排查法 | 物理层 / 驱动层 / RTOS 系统层 / 应用层 / 协议层 |
| 6. 真实设备调试闭环 | 有无 Serial Agent 时的两套执行路径 |

**RTOS 与内存（第 7–9 章）**

| 章节 | 内容 |
|---|---|
| 7. STM32 + FreeRTOS 专项 | Task 状态、栈溢出、Heap、Queue/Mutex、ISR 与 RTOS API、死锁与优先级反转 |
| 8. HardFault 分析 | 保留现场、CFSR 关键位识别、PC 到源码的符号解析 |
| 9. 内存越界与数据破坏 | 变量莫名变化时的七步排查，watchpoint、DMA 越界、对象生命周期 |

**外设与总线（第 10–15 章）**

| 章节 | 内容 |
|---|---|
| 10. DMA 调试 | Stream/Channel、外设与内存地址、数据宽度、NDTR、Buffer 生命周期 |
| 11. F7/H7 带 Cache 平台 | D-Cache Clean/Invalidate、MPU、DMA 一致性 |
| 12. UART / UART + DMA | 死掉、乱码、丢包、偶发不收数据的分层定位 |
| 13. I2C 调试 | 软件期望与总线波形逐段对比，ACK 与寄存器地址 |
| 14. SPI 调试 | CPOL/CPHA、CS 时序、SCK 频率、位序、数据宽度 |
| 15. CAN / USB 协议 | 应用期望帧 → 驱动 → 总线 → 对端 → 解析 |

**实时性与工程规范（第 16–22 章）**

| 章节 | 内容 |
|---|---|
| 16. 实时性与时序 | GPIO 翻转、DWT CYCCNT、Runtime Stats、中断执行时间、临界区长度 |
| 17. 日志策略 | 日志分级、关键字段、观测代码对原时序的影响 |
| 18. 调试决策表 | 12 种典型现象对应的第一与第二优先级 |
| 19. 修改代码的安全规则 | 八条禁止项，最小修复原则 |
| 20. Build / Flash / Verify 闭环 | 编译失败不得假设运行结果，烧录失败不得声称已更新 |
| 21. 闭环验证标准 | 六条判定条件，未过板端验证不得写问题已解决 |
| 22. 调试报告格式 | 问题 / 复现条件 / 现场证据 / 排除项 / 根因 / 修改 / 验证 / 遗留风险 |

**示例与原则（第 23–24 章）**

| 章节 | 内容 |
|---|---|
| 23. Agent 行为示例 | 三个完整案例：运行后死机、I2C 读 ID 错误、UART + DMA 偶发停止 |
| 24. 核心原则 | 七条不可妥协的底线 |

### 安装步骤

**安装本skill前提**：先安装Serial Agent，以让AI能通过串口/stink读取到你的板端信息，安装步骤请看以下仓库链接：
```markdown
https://github.com/Rance-OwO/Serial-Agent，按照该大佬仓库步骤进行安装。
```

Skill 就是一个目录。本仓库的两个 Skill 各自独立，把 `skills/` 下要用的目录整个复制到你的 Agent skills 目录即可（`embedded-debugging` 做源码级断点调试时依赖 `keil-mcp-debug`，建议一起装）。

```bash
git clone https://github.com/notnameuse/embedded-debug-skill.git
cd embedded-debug-skill
```

**Qoder（全局生效）**

```bash
mkdir -p ~/.qoder/skills
cp -r skills/embedded-debugging skills/keil-mcp-debug ~/.qoder/skills/
```

**Claude Code（全局生效）**

```bash
mkdir -p ~/.claude/skills
cp -r skills/embedded-debugging skills/keil-mcp-debug ~/.claude/skills/
```

**仅当前项目生效**

```bash
mkdir -p .qoder/skills      # 或 .claude/skills
cp -r skills/embedded-debugging skills/keil-mcp-debug .qoder/skills/
```

**用软链接代替复制**，这样 `git pull` 之后本地 Skill 自动跟着更新：

```bash
ln -s "$(pwd)/skills/embedded-debugging" ~/.qoder/skills/embedded-debugging
ln -s "$(pwd)/skills/keil-mcp-debug" ~/.qoder/skills/keil-mcp-debug
```

> `keil-mcp-debug` 是**按工作区**加载的引导式技能（仅 Windows + ST-Link + STM32F4）：首次使用需探测/登记工具链、把 `gdb` 写进工作区 `.qoder/mcp.json`，详细步骤见其 `SKILL.md`。

安装完成后重启 Agent 会话。当你提到 STM32、FreeRTOS、HardFault、DMA、串口日志、烧录、开发板调试这类关键词时，Skill 会自动触发；也可以直接要求 Agent 使用 embedded-debugging。

**也可以让Agent帮你装，复制下述内容给你的Agent即可**：
```markdown
请安装skill:https://github.com/notnameuse/embedded-debug-skill，要能在工作区调用，安装完成后测试是否能成功触发。
```

### 依赖说明

这个 Skill 本身不连接任何硬件，它只是决策规范。要跑通完整闭环，需要设备侧执行层通过 MCP 提供以下能力：

| 能力 | 用途 |
|---|---|
| 设备连接 / 状态检查 | 确认目标板在线、调试器识别正常 |
| 串口打开 / 发送 / 持续监控 / 读取日志 | 采集现场日志，验证运行行为 |
| 设备复位 / 启动 / 停止 | 复现问题，验证修复 |
| Debugger 连接 / halt / run / reset | 在 Fault 之后保留现场，而不是先复位 |
| 寄存器读取 / 内存读取 | 读 CFSR、HFSR、MMFAR、BFAR 及外设寄存器 |
| GDB 调试 | watchpoint、断点、调用栈 |
| ELF 符号解析 | 用 addr2line 把 PC / LR 映射回源码行 |
| 固件 Build | 编译并确认产出 ELF / HEX / BIN |
| 固件 Flash | 烧录到目标板 |
| 逻辑分析仪 / 示波器数据获取 | I2C / SPI / CAN / UART 波形比对 |

具体工具名以你的 MCP Server 实际提供的为准，Skill 明确禁止 Agent 虚构工具名称。

**没有这些能力时依然可用。** Skill 会退化为输出需要人工执行的最小命令和步骤，并说明需要什么数据、如何获取、获取后应该观察什么、不同结果分别意味着什么。你手工执行后把结果贴回对话，Agent 继续下一轮诊断。

### 使用示例

**示例一：FreeRTOS 运行后偶发死机**

你说：STM32F407 + FreeRTOS 跑半小时后偶尔死机。

Agent 会依次做这些事：取最后一段串口日志 → 检查有无 Fault 记录 → 能连 Debugger 就先 Halt 并读 PC/LR/SP/CFSR → 用 ELF 解析地址 → 取 Task 状态与 Stack High Water Mark → 取 Heap 当前值与历史最低值 → 根据证据判断属于栈、堆、非法访问、ISR 优先级还是竞态 → 只改最可能的那一处 → Build → Flash → 按原条件复现验证。

**示例二：I2C 读到的 Device ID 不对**

Agent 会先读软件期望的地址和寄存器，再取实际总线波形，逐段核对 Address / ACK / Register Address / Read Data，然后和软件日志里的原始字节对比。软件日志与波形不一致，问题在驱动或配置层；波形正确但最终 ID 错误，问题在接收 Buffer、字节序、长度或解析逻辑。

**示例三：UART + DMA 偶发停止收数据**

Agent 会查 UART error flags、DMA 状态与 NDTR、RingBuffer 读写索引、RX Task 状态、ISR 里调用的 RTOS API、Buffer 生命周期与越界。修复后要求持续运行测试，而不是只跑一次就算通过。

### 核心原则

1. 证据优先于猜测。
2. 真实设备数据优先于静态代码推测。
3. Skill 决定调试策略，Serial Agent / MCP 执行设备操作。
4. 一次验证一个主要假设。
5. 修改后必须 Build、Flash、Run、Verify。
6. 没有完成板端验证，就不要声称问题已经解决。
7. 优先最小改动，不为了绕过问题而破坏系统设计。

第 6 条是这个 Skill 最硬的约束。无法完成真实设备验证时，Agent 只能写：代码层修复已完成，但尚未完成板端验证。

### 仓库结构

```text
embedded-debug-skill/
├── README.md
├── LICENSE                          # MIT
└── skills/
    ├── embedded-debugging/
    │   └── SKILL.md                 # 通用调试方法论，24 章
    └── keil-mcp-debug/              # STM32F4 源码级在线调试链路（仅 Windows）
        ├── SKILL.md                 # 引导式技能
        ├── config/
        │   └── toolchain.example.json
        └── scripts/                 # env-doctor / dwarf-check / debug_start / debug_stop / openocd_halt / lib\common.ps1
```

后续新增的 Skill 会平铺在 `skills/` 下。


### 参考文献
[1]https://github.com/Rance-OwO/Serial-Agent

[2]https://github.com/shangliny10-lab/embedded-skills
---

## English

### What it does

Embedded debugging is hard because information is scarce. The board is dead with no stack trace, a task is stuck with no log, an intermittent fault takes half an hour to reproduce. In that situation most AI assistants degrade into guessing: they read the code once, offer three plausible causes, and leave you to try them all.

This skill constrains how the agent debugs. It defines what to check first, what to check next based on each result, what counts as evidence for a root cause, and when the agent is forbidden from claiming the problem is fixed. The whole thing rests on one position:

> Evidence over guesswork. Real device data over static code speculation.

It also draws a hard line on responsibility. The skill owns debugging strategy; the Serial Agent / MCP owns actually connecting to the device, collecting data, building, flashing, and verifying. When a capability is missing from the environment, the agent must fall back to giving you the minimal manual steps — it may not pretend to have executed something.

### Skills in this repo

This repo ships two cooperating skills:

| Skill | Role |
|---|---|
| `embedded-debugging` | General embedded-debugging methodology plus the Serial Agent/MCP build/flash/serial loop (a decision spec; it drives no hardware itself) |
| `keil-mcp-debug` | Source-level online debugging for STM32F4 + ST-Link via mcp-gdb + arm-none-eabi-gdb + OpenOCD — breakpoints, stepping, variables, memory, call stacks (Windows only) |

`embedded-debugging` delegates to `keil-mcp-debug` when it needs breakpoint-level source debugging. Install both (one copy per workspace) for the full loop; each also works on its own.

### Coverage

- **Platforms**: STM32F0/F1/F2/F3/F4/F7/G0/G4/H5/H7 and other Cortex-M parts
- **RTOS**: FreeRTOS — tasks, queues, semaphores, mutexes, event groups, software timers
- **Drivers**: HAL / LL / CMSIS / bare-metal peripheral drivers
- **Toolchains**: GCC, arm-none-eabi-gcc, ARM Compiler, Keil projects
- **Debug links**: ST-Link, J-Link, OpenOCD, GDB, SWD, JTAG
- **Peripherals**: UART, I2C, SPI, CAN, USB, ADC, PWM, TIM, DMA
- **Fault classes**: HardFault / BusFault / UsageFault / MemManage, stack overflow, heap exhaustion, out-of-bounds writes, deadlock, priority inversion, race conditions, DMA and cache coherency

### How the skill is organized

SKILL.md has 24 chapters in five groups:

| Chapters | Group | Covers |
|---|---|---|
| 1–6 | Methodology | Responsibility split, scope, tool-call principles, the debugging state machine, layered triage, the on-target loop |
| 7–9 | RTOS & memory | Task state, stack overflow, heap, queues and mutexes, ISR/RTOS API rules, deadlock, HardFault analysis, memory corruption |
| 10–15 | Peripherals & buses | DMA, D-Cache on F7/H7, UART, I2C, SPI, CAN/USB |
| 16–22 | Real-time & engineering discipline | Timing measurement, logging strategy, the triage decision table, safe-edit rules, build/flash/verify, closure criteria, report format |
| 23–24 | Examples & principles | Three worked cases and seven non-negotiable rules |

Every session follows this state machine:

```text
INIT → REPRODUCE → COLLECT → HYPOTHESIS → LOCALIZE → PATCH → BUILD → FLASH → VERIFY → DONE / ITERATE
```

### Installation

**please install serial agent firstly**:
```markdown
https://github.com/Rance-OwO/Serial-Agent，
```

A skill is just a directory. Copy the skills you need from `skills/` into your agent's skills directory (`embedded-debugging` needs `keil-mcp-debug` for source-level debugging, so install both).

```bash
git clone https://github.com/notnameuse/embedded-debug-skill.git
cd embedded-debug-skill

# Qoder (user-wide)
mkdir -p ~/.qoder/skills && cp -r skills/embedded-debugging skills/keil-mcp-debug ~/.qoder/skills/

# Claude Code (user-wide)
mkdir -p ~/.claude/skills && cp -r skills/embedded-debugging skills/keil-mcp-debug ~/.claude/skills/

# Project-scoped
mkdir -p .qoder/skills && cp -r skills/embedded-debugging skills/keil-mcp-debug .qoder/skills/
```

Symlink instead of copying if you want `git pull` to keep the installed skill up to date:

```bash
ln -s "$(pwd)/skills/embedded-debugging" ~/.qoder/skills/embedded-debugging
ln -s "$(pwd)/skills/keil-mcp-debug" ~/.qoder/skills/keil-mcp-debug
```

Restart the agent session afterwards. The skill triggers on keywords like STM32, FreeRTOS, HardFault, DMA, serial log, flashing, or board debugging, and you can also invoke `embedded-debugging` explicitly.

### Prerequisites

The skill itself talks to no hardware — it is a decision spec. A full closed loop needs a device-side execution layer exposing these capabilities over MCP:

device connection and status, serial open/send/monitor/read, device reset/start/stop, debugger connect/halt/run/reset, register read, memory read, GDB, ELF symbol resolution, firmware build, firmware flash, and logic analyzer or oscilloscope capture where available.

Exact tool names come from whatever your MCP server actually provides; the skill explicitly forbids the agent from inventing tool names.

**It still works without them.** The skill degrades to printing the minimal manual commands and steps, stating what data is needed, how to get it, what to look at once you have it, and what each possible result implies. You run them by hand, paste the output back, and the agent continues the next diagnostic round.

### Core principles

1. Evidence over guesswork.
2. Real device data over static code speculation.
3. The skill decides debugging strategy; the Serial Agent / MCP performs device operations.
4. Verify one main hypothesis at a time.
5. After any change: build, flash, run, verify.
6. Never claim the problem is solved without on-target verification.
7. Prefer the minimal fix; do not break the system design to route around a problem.

Rule 6 is the hardest constraint here. When real-device verification is not possible, the agent may only state: the code-level fix is complete, but on-target verification has not been done.

### reference
[1]https://github.com/Rance-OwO/Serial-Agent

[2]https://github.com/shangliny10-lab/embedded-skills
---

## License

[MIT](LICENSE) © 2026 notnameuse

---
name: embedded-debugging
description: 面向真实嵌入式设备的系统化调试 Skill。重点覆盖 STM32/ARM Cortex-M + FreeRTOS 场景，并通过 Serial Agent/MCP 能力完成“获取现场→分析→修改→编译→烧录→运行→验证”的闭环。用户提及 STM32、FreeRTOS、HardFault、I2C/SPI/UART/CAN、DMA、RTOS 任务异常、死机、偶发故障、串口日志、SWD/JTAG、GDB、逻辑分析仪、示波器、固件烧录或需要连接真实开发板进行调试时使用。
---

# Embedded Debugging Skill V2

## 1. 定位

本 Skill 不是单纯的嵌入式知识库，而是 AI Agent 在真实 STM32 + RTOS 项目中的**调试决策与执行规范**。

核心原则：

> Skill 负责“怎么查、先查什么、根据结果下一步查什么”；Serial Agent / MCP 负责“实际连接设备、采集数据、执行命令、烧录和验证”。

目标是把：

```text
用户描述问题
  ↓
故障分类
  ↓
建立假设
  ↓
选择最小成本的现场信息
  ↓
调用 Serial Agent / MCP 获取真实数据
  ↓
证据驱动地缩小范围
  ↓
修改代码或配置
  ↓
Build
  ↓
Flash
  ↓
Reset / Run
  ↓
Serial Monitor / Debugger 验证
  ↓
问题解决？
  ├─ 是 → 输出根因与修复
  └─ 否 → 保留证据，进入下一轮诊断
```

禁止把“猜测”当成“定位结果”。如果缺少现场数据，应明确说明缺什么数据，并优先通过可用工具获取。

---

## 2. 适用范围

重点支持：

- STM32F0/F1/F2/F3/F4/F7/G0/G4/H5/H7 等 Cortex-M 平台
- FreeRTOS 项目
- HAL / LL / CMSIS / 裸机外设驱动
- GCC / arm-none-eabi-gcc / ARM Compiler / Keil 工程
- ST-Link / J-Link / OpenOCD 等调试链路
- UART / I2C / SPI / CAN / USB / ADC / PWM / TIM / DMA
- RTOS Task / Queue / Semaphore / Mutex / EventGroup / Software Timer
- HardFault / BusFault / UsageFault / MemManage
- 栈溢出、堆耗尽、内存越界、死锁、优先级反转、竞态条件
- DMA、Cache、MPU、内存一致性问题
- 真实板卡上的串口、调试器、逻辑分析仪、示波器闭环验证

如果问题明显属于纯硬件故障，应先使用工具验证电源、时钟、连接和波形，而不是直接修改固件。

---

## 3. 工具与职责边界

### 3.1 Skill

Skill 负责：

- 故障分类
- 调试优先级
- 假设树
- 证据判断
- 下一步动作选择
- 修改策略
- 验证标准

### 3.2 Serial Agent / MCP

Serial Agent 是设备侧执行层。实际项目中可通过 MCP 暴露以下能力，**具体工具名以当前 MCP Server 实际提供的工具为准，不得虚构工具名称**：

```text
设备连接 / 状态检查
串口打开、关闭、发送、持续监控、读取日志
设备复位、启动、停止
Debugger 连接、halt、run、reset
寄存器读取
内存读取
GDB 调试
ELF 符号解析
固件 Build
固件 Flash / Download
逻辑分析仪 / 示波器数据获取（如果已接入）
```

如果当前环境没有某项能力，不得假装执行；应退化为“给出需要人工执行的最小操作”。

### 3.3 工具调用原则

1. **先观察，后修改。**
2. **先低风险采集，后 halt/reset。**
3. 能通过日志解决的问题，不优先启动复杂调试链路。
4. 能通过一次现场采集排除一大片假设，不要连续尝试随机修改。
5. 修改代码前保留原始现象和关键证据。
6. Flash 前确认当前固件、目标板、连接状态正确。
7. 修改后必须验证，不能以“编译通过”作为问题解决依据。

---

## 4. 标准调试状态机

每次进入本 Skill，建立如下状态：

```text
INIT
 ↓
REPRODUCE
 ↓
COLLECT
 ↓
HYPOTHESIS
 ↓
LOCALIZE
 ↓
PATCH
 ↓
BUILD
 ↓
FLASH
 ↓
VERIFY
 ↓
DONE / ITERATE
```

### INIT

确认：

- MCU 型号
- RTOS 类型及版本（如果已知）
- 编译器 / 工程系统
- 当前固件版本或 Git commit
- 调试器类型
- 串口信息
- 问题出现条件
- 是否可以稳定复现

### REPRODUCE

优先寻找：

- 固定输入
- 固定时序
- 特定任务
- 特定通信包
- 温度 / 电压条件
- 上电后时间
- 复位次数
- 高负载条件

如果问题偶发，应记录“出现频率”和“触发条件”，不要立即修改代码。

### COLLECT

根据故障类型选择最小必要数据。

### HYPOTHESIS

建立不超过 3~5 个高概率假设，并给每个假设定义验证手段。

### LOCALIZE

优先获得能直接缩小范围的证据：PC、LR、Fault 状态、任务状态、日志、寄存器、波形、队列状态等。

### PATCH

只修改能够解释现象的代码或配置，避免一次改动大量无关模块。

### BUILD / FLASH / VERIFY

完整验证修改后的行为。

---

## 5. 分层排查法

统一按照以下层次思考：

```text
物理层
 ↓
时钟 / 电源 / GPIO / 电平 / 连接
 ↓
驱动层
 ↓
寄存器 / 外设初始化 / ISR / DMA
 ↓
RTOS系统层
 ↓
Task / Queue / Mutex / Heap / Stack / Scheduler
 ↓
应用层
 ↓
状态机 / 业务逻辑 / 数据处理
 ↓
协议层
 ↓
通信时序 / 帧格式 / CRC / 超时 / 重试
```

出现通信异常时不要默认是协议问题；出现 HardFault 时不要默认是指针问题；出现任务卡死时不要默认是死锁。先用证据确认所在层级。

---

## 6. 真实设备调试闭环

### 6.1 有 Serial Agent 时

如果当前环境提供 Serial Agent/MCP：

1. 检查设备连接状态。
2. 获取已有串口日志。
3. 根据问题类型选择 Debugger / Serial / Logic Analyzer 等能力。
4. 采集现场。
5. 分析数据。
6. 如果需要代码修复，先定位源码。
7. 修改最小范围代码。
8. Build。
9. 检查 Build 是否成功以及是否产生目标 ELF/HEX/BIN。
10. 确认目标设备后 Flash。
11. Reset / Run。
12. 自动或半自动收集验证日志。
13. 判断问题是否消失。
14. 如果未解决，保留本轮证据并进入下一轮，不要重复同一假设。

### 6.2 没有 Serial Agent 时

提供人工执行的最小命令或操作步骤，并明确指出：

- 需要什么数据
- 如何获取
- 获取后应该观察什么
- 不同结果分别意味着什么

---

# 7. STM32 + FreeRTOS 专项

## 7.1 Task 状态

重点关注：

- Running
- Ready
- Blocked
- Suspended
- Deleted
- Task priority
- Stack High Water Mark
- Runtime statistics（如果启用）

优先使用项目已有的 FreeRTOS API 或调试接口，例如：

```c
uxTaskGetStackHighWaterMark(taskHandle);
uxTaskGetSystemState(...);
vTaskGetInfo(...);
```

不要为了调试强行引入复杂统计代码，优先使用已有配置。

## 7.2 栈溢出

重点检查：

```c
uxTaskGetStackHighWaterMark(taskHandle);
```

以及：

- 大数组是否定义在 Task 栈上
- 深层函数调用
- printf / sprintf / 浮点格式化造成的栈压力
- 递归
- ISR 栈使用
- FreeRTOS stack overflow hook

如果多个 Task 同时出现异常，优先考虑系统性内存破坏，而不是逐个怀疑业务代码。

## 7.3 Heap

检查：

```c
xPortGetFreeHeapSize();
xPortGetMinimumEverFreeHeapSize();
```

重点区分：

- 当前剩余 Heap
- 历史最低 Heap
- 分配失败
- 内存碎片
- 长期增长

## 7.4 Queue / Semaphore / Mutex

检查：

- 队列是否满
- 队列是否长期为空
- Sender / Receiver 是否匹配
- Block timeout 是否合理
- Mutex 是否长期未释放
- 是否存在锁顺序反转
- 是否在 ISR 中错误调用非 FromISR API

## 7.5 ISR + FreeRTOS

典型规则：

```text
ISR
 ↓
FromISR API
 ↓
必要时触发任务切换
```

重点检查：

- `xQueueSendFromISR`
- `xSemaphoreGiveFromISR`
- `vTaskNotifyGiveFromISR`
- `portYIELD_FROM_ISR`
- NVIC 优先级
- `configMAX_SYSCALL_INTERRUPT_PRIORITY` 等配置

如果出现“偶发 HardFault + 某外设中断高频触发”，优先检查 ISR 与 FreeRTOS API/优先级关系。

## 7.6 死锁与优先级反转

出现“任务不再运行但 MCU 没死机”时，检查：

```text
Task 状态
 ↓
等待对象
 ↓
持锁 Task
 ↓
持锁 Task 是否仍运行
 ↓
Priority
 ↓
锁顺序
```

如果高优先级任务等待低优先级任务持有的 Mutex，而中优先级任务持续运行，应考虑 Priority Inversion，并检查是否启用了适当的优先级继承机制。

---

# 8. HardFault / BusFault / UsageFault

## 8.1 第一优先级：保留现场

至少获取：

```text
PC
LR
SP
xPSR
R0-R3
R12
HFSR
CFSR
MMFAR
BFAR
```

如果 Debugger 可以在 Fault 后 Halt，应优先直接读取现场，不要先 Reset。

## 8.2 Cortex-M Fault 分析

```text
HardFault
 ├─ MemManage
 ├─ BusFault
 └─ UsageFault
```

CFSR 是核心证据来源。

重点识别：

- IACCVIOL
- DACCVIOL
- PRECISERR
- IMPRECISERR
- UNDEFINSTR
- INVSTATE
- INVPC
- UNALIGNED
- DIVBYZERO
- NOCP

## 8.3 PC → 源码

使用 ELF 做符号解析：

```bash
arm-none-eabi-addr2line -e firmware.elf -f -C -p 0x08001234
```

同时解析 LR 和必要的调用栈地址。

不要只看 PC 就下结论：

- PC 落在有效代码区：继续分析调用路径和 Fault 类型。
- PC 为异常地址：检查函数指针、栈破坏、返回地址破坏。
- PC 落在 Flash 之外：检查内存破坏、栈或函数指针。

---

# 9. 内存越界与数据破坏

当“某变量莫名其妙变化”时，不要只打印变量。

优先：

1. 确认变量地址。
2. 检查相邻内存对象。
3. 使用 GDB watchpoint（如果硬件资源允许）。
4. 检查 DMA 是否写越界。
5. 检查数组长度与 memcpy/memset 长度。
6. 检查 ISR 与 Task 是否并发访问。
7. 检查生命周期：对象是否已经释放或离开作用域。

如果问题只能在高负载时出现，优先检查竞态、DMA、缓存和栈破坏。

---

# 10. DMA 调试

DMA 异常至少检查：

```text
DMA Stream/Channel
 ↓
外设地址
 ↓
内存地址
 ↓
数据宽度
 ↓
传输数量
 ↓
Increment
 ↓
Circular / Normal
 ↓
NDTR
 ↓
Transfer Complete / Half Complete / Error
```

特别关注：

- Buffer 长度是否正确
- DMA 是否越界
- Buffer 生命周期是否覆盖整个 DMA 传输周期
- 中断是否重复处理
- Cache 是否一致
- DMA 与 CPU 是否同时访问同一 Buffer

---

# 11. STM32F7/H7 等带 Cache 平台

当出现：

- DMA 收到的数据“偶尔不更新”
- CPU 看见的数据与外设实际数据不一致
- 相同代码在 F4 正常、H7 异常

优先考虑：

```text
D-Cache
 ↓
Clean / Invalidate
 ↓
DMA 可访问内存区域
 ↓
MPU / Memory Attribute
```

不要在没有证据时随意关闭 Cache。优先确认 Buffer 所在内存、Cache 状态和 DMA 一致性处理。

---

# 12. UART / UART + DMA

遇到“串口死掉、乱码、丢包、偶发不收数据”：

```text
软件配置
 ↓
UART寄存器
 ↓
TX/RX波形
 ↓
DMA状态
 ↓
RingBuffer
 ↓
ISR
 ↓
RTOS Task
 ↓
协议解析
```

检查：

- 波特率
- 数据位/停止位/校验
- Overrun / Framing / Noise 等错误
- DMA NDTR
- Buffer 是否越界
- 环形缓冲区读写索引
- ISR 是否丢事件
- Task 是否长期 Blocked
- 发送是否阻塞在锁或队列

---

# 13. I2C 调试

当“读到错误 Device ID / Register Value”时，必须区分：

```text
软件期望
 ↓
实际 I2C Address
 ↓
START
 ↓
Address + R/W
 ↓
ACK/NACK
 ↓
Register Address
 ↓
Repeated START
 ↓
Read Address
 ↓
Slave Data
 ↓
STOP
 ↓
软件解析
```

建议同时获得：

- 软件发送地址
- 逻辑分析仪实际地址
- ACK 状态
- Register Address
- 实际返回字节
- 驱动层最终解析值

如果软件日志与波形不一致，优先检查驱动/配置；如果波形正确但最终 ID 错误，优先检查软件接收 Buffer、字节序、长度和解析逻辑。

---

# 14. SPI 调试

检查：

- CPOL / CPHA
- CS 时序
- SCK 频率
- Bit order
- 数据宽度
- DMA 长度
- RX/TX buffer
- CS 是否在整个事务期间保持有效

不要只看“有时钟”就认为 SPI 正常。

---

# 15. CAN / USB 等协议调试

统一采用：

```text
应用期望帧
 ↓
驱动实际发送
 ↓
总线实际波形/帧
 ↓
对端响应
 ↓
驱动接收
 ↓
协议解析
```

对任何协议问题，优先寻找“软件日志与物理链路之间的差异”。

---

# 16. 实时性与时序

当问题描述包含：

- 偶发
- 高负载
- 超时
- 抖动
- 丢周期
- 电机控制不稳定
- 音频/采样不连续

优先考虑实时性。

可以使用：

- GPIO 翻转 + 示波器/逻辑分析仪
- DWT CYCCNT
- FreeRTOS Runtime Stats
- Task 状态
- 中断执行时间
- 临界区长度

DWT 示例：

```c
DWT->CTRL |= DWT_CTRL_CYCCNTENA_Msk;
DWT->CYCCNT = 0;
uint32_t start = DWT->CYCCNT;
/* code */
uint32_t cycles = DWT->CYCCNT - start;
```

必须结合 CPU 主频换算时间，不要把 cycle 数直接当微秒。

---

# 17. 日志策略

日志必须服务于定位，而不是无限打印。

推荐：

```text
ERROR > WARN > INFO > DEBUG
```

关键日志包含：

```text
timestamp
module
event
status/error code
关键参数
```

实时任务中避免大量阻塞式 `printf`。如果日志本身可能改变时序，应明确标记“观测代码可能影响原问题”。

---

# 18. 调试决策表

| 现象 | 第一优先级 | 第二优先级 |
|---|---|---|
| HardFault | PC/LR/SP/CFSR | Task/Stack/Memory |
| 任务卡死 | Task State | Mutex/Queue/ISR |
| 偶发死机 | Fault现场 | Stack/Heap/Race |
| I2C ID错误 | 波形+ACK | Buffer/地址/寄存器 |
| UART乱码 | 配置+波形 | DMA/Buffer |
| UART偶发丢包 | DMA/ISR | RingBuffer/Task |
| SPI读错 | CPOL/CPHA/CS | DMA/数据宽度 |
| CAN异常 | 实际总线帧 | 驱动/协议 |
| DMA数据错误 | NDTR/地址/长度 | Cache/Buffer |
| 高负载异常 | CPU/Task时间 | ISR/临界区 |
| 内存越来越少 | Heap趋势 | 泄漏/碎片 |
| 重启后异常 | Reset原因 | 启动顺序/初始化 |

---

# 19. 修改代码的安全规则

### 不允许

- 没有现场证据就大范围重构
- 为了“让它不崩”直接吞掉 Fault
- 无理由提高所有 Task 优先级
- 无理由增加所有 Stack
- 无理由关闭 Cache
- 无理由关闭中断
- 通过无限重试掩盖底层错误
- 直接修改生产配置而不说明

### 推荐

```text
先记录现象
 ↓
提出假设
 ↓
设计最小验证
 ↓
验证假设
 ↓
最小修复
 ↓
回归验证
```

---

# 20. Build / Flash / Verify 闭环

代码修改后必须执行：

```text
Build
 ↓
检查错误/警告
 ↓
确认 ELF/HEX/BIN
 ↓
连接目标板
 ↓
确认 MCU/调试器
 ↓
Flash
 ↓
Verify
 ↓
Reset
 ↓
Run
 ↓
收集日志
```

如果 Build 失败，不得继续假设运行结果。

如果 Flash 失败，不得声称固件已更新。告诉用户，让用户自己在keil中编译烧录后告诉你

如果设备无法连接，应报告连接失败，不得假装执行。

---

# 21. 闭环验证标准

“修复完成”必须至少满足：

1. 原问题能够复现时，复现条件再次执行后问题消失；或
2. 已经通过直接证据证明根因并完成针对性修复；且
3. Build 成功；且
4. 固件成功烧录并运行；且
5. 关键功能回归正常；且
6. 没有引入新的 Fault、死锁、资源泄漏或明显实时性退化。

如果无法完成真实设备验证，应明确写：

> “代码层修复已完成，但尚未完成板端验证。”

不得写成“问题已解决”。

---

# 22. 调试报告格式

每次完整调试结束后输出：

```text
## 问题

## 复现条件

## 现场证据

## 排除项

## 根因

## 修改

## Build结果

## Flash结果

## 板端验证

## 最终结论

## 遗留风险
```

根因必须区分：

- 已证实
- 高概率
- 尚未验证

---

# 23. Agent 行为示例

## 示例 A：FreeRTOS 运行后死机

用户：

> STM32F407 + FreeRTOS 跑半小时后偶尔死机。

Agent 应：

1. 获取最后一段串口日志。
2. 检查是否有 Fault 日志。
3. 如果能连接 Debugger，优先 Halt 并获取 PC/LR/SP/CFSR。
4. 用 ELF 解析 PC/LR。
5. 获取 Task 状态与 Stack High Water Mark。
6. 获取 Heap 当前值和历史最低值（如果可用）。
7. 根据证据判断是栈、堆、非法访问、ISR/RTOS 优先级还是竞态。
8. 只修改最可能的根因。
9. Build → Flash → Run。
10. 重现原条件进行验证。

## 示例 B：I2C 读 ID 错误

Agent 应：

1. 读取软件期望地址和寄存器。
2. 获取实际 I2C 波形（如果工具可用）。
3. 检查 Address / ACK / Register Address / Read Data。
4. 对比软件日志中的原始字节。
5. 定位到地址、时序、驱动、Buffer 或解析层。
6. 修复并重新烧录。
7. 再次读取 ID 并验证。

## 示例 C：UART + DMA 偶发停止

Agent 应：

1. 获取最后日志。
2. 检查 UART error flags。
3. 获取 DMA 状态和 NDTR。
4. 检查 RingBuffer 索引。
5. 检查 RX Task 状态。
6. 检查 ISR 使用的 RTOS API。
7. 检查 Buffer 生命周期和越界。
8. 修复后进行持续运行测试，而不是只测试一次。

---

# 24. 核心原则

始终遵守以下原则：

> **证据优先于猜测。**

> **真实设备数据优先于静态代码推测。**

> **Skill 决定调试策略，Serial Agent/MCP 执行设备操作。**

> **一次验证一个主要假设。**

> **修改后必须 Build、Flash、Run、Verify。**

> **没有完成板端验证，就不要声称问题已经解决。**

> **优先最小改动，不为了绕过问题而破坏系统设计。**

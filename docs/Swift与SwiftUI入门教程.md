# 结合 Egangnal 学习 Swift 与 SwiftUI

这是一份面向初学者的 Swift + SwiftUI 入门教程。它不会从 Egangnal 最复杂的计时、数据库事务或主题快照动画开始，而是先建立语言基础，再用一个简化的“英语/日语空间选择器”贯穿 SwiftUI 学习，最后告诉你如何回到真实项目继续阅读。

> 项目当前使用 Swift 6、SwiftUI 和 macOS 15.0+。教程代码以理解核心概念为第一目标，部分示例是从项目中提炼出的教学简化版，并不等同于完整业务实现。

建议分两次阅读。第一次先学习第 1～14 节和第 16～23 节，然后直接完成第 32 节的贯穿练习；第 15 节并发、第 24～31 节的应用状态与框架能力，以及第 34～36 节的持久化和测试，可以在练习跑通后第二次阅读。这样既保留完整知识地图，也能更早获得一个可运行结果。

## 1. Swift 和 SwiftUI 分别是什么

### 1.1 Swift 是编程语言

Swift 负责表达数据、条件、函数、对象和业务规则。它的角色类似于 Java 项目中的 Java 语言。

```swift
let languageName = "英语"
let learnedHours = 12.5

func summary() -> String {
    "\(languageName)：\(learnedHours) 小时"
}
```

这段代码没有界面。它只是创建数据，并用函数把数据转换成一句文字。

### 1.2 SwiftUI 是界面框架

SwiftUI 使用 Swift 语法描述窗口中应该出现什么：

```swift
import SwiftUI

struct SummaryView: View {
    var body: some View {
        Text("英语：12.5 小时")
    }
}
```

`Text`、`Button`、`HStack`、`VStack` 都来自 SwiftUI。SwiftUI 会跟踪 `body` 读取的 `@State`、Binding、Environment 以及 Observation 可观察属性；这些受支持的数据发生变化后，相关界面会重新计算，并把必要变化更新到窗口上。普通 `var` 并不会自动产生这种效果。

可以先这样记：

```text
Swift       = 语言、数据、规则
SwiftUI     = 用 Swift 写界面
SwiftData   = 用 Swift 模型保存本地结构化数据
AppKit      = 更底层的 macOS 原生界面与系统能力
```

## 2. 在 Xcode 中认识一个 Swift 文件

一个常见 Swift 文件可能是这样：

```swift
import SwiftUI

struct WelcomeView: View {
    let name: String

    var body: some View {
        Text("你好，\(name)")
    }
}
```

逐项解释：

- `import SwiftUI`：导入 SwiftUI 模块，之后才能使用 `View` 和 `Text`。
- `struct`：声明一个结构体类型。
- `WelcomeView`：类型名。Swift 类型通常使用大驼峰命名。
- `: View`：表示 `WelcomeView` 遵守 `View` 协议，能够成为 SwiftUI 界面。
- `let name: String`：这个 View 接收一个不可变字符串。
- `var body: some View`：SwiftUI 要求每个 View 提供的界面描述。
- `Text(...)`：创建一个文本视图。
- `\(name)`：字符串插值，把变量值放进字符串。

Swift 使用花括号 `{}` 表示作用域，通常不需要在语句末尾写分号。

## 3. 常量、变量和基本类型

### 3.1 `let` 与 `var`

```swift
let appName = "Egangnal"
var currentHours = 0.0

currentHours = 0.5
```

- `let` 声明常量，初始化后不能再次赋值。
- `var` 声明变量，之后可以改变。

应该优先使用 `let`。只有值确实需要变化时才使用 `var`。这样可以减少意外修改，也让阅读者更快理解数据所有权。

下面的代码不能通过编译：

```swift
let language = "英语"
language = "日语" // 错误：let 常量不能重新赋值
```

### 3.2 常见基本类型

```swift
let title: String = "英语"
let entryCount: Int = 20
let learnedHours: Double = 12.5
let isActive: Bool = true
```

- `String`：文字。
- `Int`：整数。
- `Double`：双精度小数。
- `Bool`：布尔值，只有 `true` 和 `false`。

冒号后的内容是类型标注。Swift 通常可以从右侧推断类型：

```swift
let title = "英语"       // 推断为 String
let entryCount = 20     // 推断为 Int
let learnedHours = 12.5 // 推断为 Double
```

当推断结果明确时，不必重复写类型；当空集合、协议类型或数字精度可能产生歧义时，应显式标注。

### 3.3 字符串插值

```swift
let language = "日语"
let hours = 8.2
let text = "\(language)学习时长：\(hours) 小时"
```

字符串中的 `\(...)` 会先计算括号内表达式，再把结果转换为文字。这比用多个 `+` 拼接不同类型更安全。

### 3.4 数字运算和类型不能随意混用

```swift
let seconds = 3_600.0
let hours = seconds / 3_600.0
```

下划线只帮助阅读，不改变数字值。Swift 不会自动把所有数字类型混在一起：

```swift
let count: Int = 2
let hours: Double = 1.5
let total = Double(count) + hours
```

`Double(count)` 是显式类型转换。Swift 要求明确转换，可以减少精度和符号问题。

## 4. 条件和循环

### 4.1 `if`

```swift
let hours = 65.0

if hours > 50.0 {
    print("进入蓝色阶段")
} else {
    print("使用默认文字颜色")
}
```

条件必须是 `Bool`。Swift 不允许用 `0`、空字符串或对象本身冒充真假值。

多个区间可以写成：

```swift
if hours <= 50.0 {
    print("默认颜色")
} else if hours <= 100.0 {
    print("蓝色")
} else if hours <= 300.0 {
    print("紫色")
} else {
    print("橙色")
}
```

因为前面的条件已经被排除，第二个分支实际表达 `50 < hours <= 100`。

### 4.2 `switch`

当一个值只有几种明确状态时，`switch` 通常比多个 `if` 更清楚：

```swift
enum ThemeMode {
    case light
    case dark
}

let mode = ThemeMode.dark

switch mode {
case .light:
    print("浅色主题")
case .dark:
    print("深色主题")
}
```

Swift 的 `switch` 必须穷尽所有可能情况。这里枚举只有两种状态，所以两个 `case` 都要处理。穷尽性让未来新增状态时，编译器能提醒所有需要同步修改的位置。

### 4.3 `for-in`

```swift
let languages = ["英语", "日语"]

for language in languages {
    print(language)
}
```

`language` 会依次取得数组中的每个元素。范围也可以循环：

```swift
for page in 1...3 {
    print("第 \(page) 页")
}
```

`1...3` 包含 1、2、3；`1..<3` 只包含 1、2。

## 5. 函数

### 5.1 参数和返回值

```swift
import Foundation

func formattedHours(seconds: Double) -> String {
    let hours = seconds / 3_600.0
    return String(format: "%.1f 小时", hours)
}
```

- `func`：声明函数。
- `formattedHours`：函数名。
- `seconds: Double`：参数名和类型。
- `-> String`：函数返回字符串。
- `return`：把结果交给调用者。

调用方式：

```swift
let text = formattedHours(seconds: 7_200)
```

Swift 默认把参数名也作为调用标签，所以调用处写 `seconds:`。标签让代码读起来更接近一句话。

### 5.2 外部参数标签

```swift
func greeting(for language: String) -> String {
    "开始学习\(language)"
}

let text = greeting(for: "英语")
```

`for` 是调用时使用的外部标签，`language` 是函数内部使用的参数名。

如果不希望出现调用标签，可以使用下划线：

```swift
func doubled(_ value: Int) -> Int {
    value * 2
}

let result = doubled(10)
```

### 5.3 单表达式省略 `return`

如果函数或计算属性只有一个表达式，Swift 可以省略 `return`：

```swift
func hourValue(seconds: Double) -> Double {
    seconds / 3_600.0
}
```

Egangnal 中许多很短的计算属性采用这种写法。初学时如果不确定，也可以明确写出 `return`。

## 6. 枚举：用类型表达有限状态

真实项目中的 [`LanguageSpace.swift`](../Egangnal/Domain/LanguageSpace.swift) 使用枚举定义两门语言。下面先看教学简化版：

```swift
enum LanguageSpace: String, CaseIterable, Identifiable {
    case english
    case japanese

    var id: Self { self }

    var title: String {
        switch self {
        case .english:
            "英语"
        case .japanese:
            "日语"
        }
    }
}
```

逐项解释：

- `enum LanguageSpace`：创建一个名为 `LanguageSpace` 的枚举类型。
- `case english`、`case japanese`：它只有两个合法值。
- `: String`：每个 case 同时拥有字符串原始值，分别是 `"english"` 和 `"japanese"`。
- `CaseIterable`：编译器生成 `LanguageSpace.allCases`，方便遍历全部语言。
- `Identifiable`：类型提供稳定的 `id`，SwiftUI 的 `ForEach` 可以识别每个元素。
- `Self`：当前类型本身，这里等同于 `LanguageSpace`。
- `self`：当前枚举值，例如 `.english`。
- `title`：计算属性。它不额外保存数据，而是根据当前 case 计算中文名称。

使用方式：

```swift
let space = LanguageSpace.english
print(space.title)     // 英语
print(space.rawValue)  // english

for item in LanguageSpace.allCases {
    print(item.title)
}
```

相比用字符串保存当前语言，枚举能防止拼写错误：

```swift
let language = "Engilsh" // 编译器不知道拼错了
let space = LanguageSpace.english // 只能选择已声明的合法 case
```

这就是“用类型表达有效状态”的基本思想。

## 7. 结构体与值类型

### 7.1 定义结构体

```swift
struct StudySummary {
    let language: LanguageSpace
    var seconds: Double

    var hours: Double {
        seconds / 3_600.0
    }
}
```

创建实例：

```swift
var summary = StudySummary(language: .english, seconds: 7_200)
print(summary.hours) // 2.0

summary.seconds += 1_800
print(summary.hours) // 2.5
```

当结构体没有声明会取代它的自定义初始化器，且访问级别允许时，编译器通常会生成成员初始化器，所以这里可以写 `StudySummary(language:seconds:)`。

### 7.2 值语义

结构体是值类型。赋值时得到一个独立副本：

```swift
var english = StudySummary(language: .english, seconds: 3_600)
var copied = english

copied.seconds = 7_200

print(english.seconds) // 3600
print(copied.seconds)  // 7200
```

修改 `copied` 不会改变 `english`。SwiftUI 的 View 也是结构体；它更像某一时刻的界面描述，而不是一个长期存活、可以任意修改的传统控件对象。

### 7.3 初始化器和校验

真实项目的 `CalendarMonth` 需要保证月份在 1 到 12 之间：

```swift
struct CalendarMonth {
    let year: Int
    let month: Int

    init(year: Int, month: Int) {
        precondition((1...12).contains(month), "月份必须在 1 到 12 之间")
        self.year = year
        self.month = month
    }
}
```

- `init` 是初始化器。
- 参数名和属性名相同时，`self.month` 表示实例属性，`month` 表示传入参数。
- `precondition` 表示调用者必须满足的程序前提。违反时程序会停止，因此只适合开发者能够保证的不变量，不适合普通用户输入校验。

## 8. 类与引用类型

类使用 `class` 声明：

```swift
final class Counter {
    var value = 0
}

let first = Counter()
let second = first
second.value = 10

print(first.value) // 10
```

类是引用类型。`first` 和 `second` 指向同一个对象，所以从任一引用修改都会被另一方看到。

`final` 表示不允许其他类继承它。Egangnal 的 Store 通常写成 `final class`，因为它们需要长期持有可变化状态，又没有通过继承扩展的需求。

结构体与类的入门选择原则：

| 需求 | 通常选择 |
| --- | --- |
| 轻量数据、复制后应互不影响 | `struct` |
| 有限状态集合 | `enum` |
| 需要共享同一份可变状态或对象身份 | `class` |
| SwiftUI 页面描述 | `struct` |
| 可观察的应用 Store | `final class` |

## 9. Optional：值可能不存在

### 9.1 为什么需要 Optional

普通 `String` 必须始终有值：

```swift
let nickname: String = "LBH"
```

如果昵称可能没有设置，要写成 `String?`：

```swift
var nickname: String? = nil
nickname = "LBH"
```

`String?` 读作“可选字符串”，它要么包含一个 `String`，要么是 `nil`。

### 9.2 `if let` 解包

```swift
if let nickname {
    print("你好，\(nickname)")
} else {
    print("尚未设置昵称")
}
```

只有 Optional 中确实有值时，`if let` 内部的 `nickname` 才是普通 `String`。

完整写法也可以是：

```swift
if let savedName = nickname {
    print(savedName)
}
```

### 9.3 `guard let` 提前退出

```swift
import Foundation

func normalizedName(_ input: String?) -> String? {
    guard let input else { return nil }

    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    return trimmed
}
```

`guard` 要求条件必须成立才能继续执行；不成立时必须离开当前作用域，例如 `return`。它适合把失败情况放在前面，让主要流程减少缩进。

### 9.4 默认值和可选链

```swift
let displayName = nickname ?? "学习者"
let characterCount = nickname?.count
```

- `??`：如果左侧为 `nil`，使用右侧默认值。
- `?.`：只有左侧有值时才继续访问；因此 `characterCount` 的类型是 `Int?`。

不要为了省事频繁使用 `!` 强制解包。值为 `nil` 时，`nickname!` 会直接让应用崩溃。只有逻辑已经严格保证值存在时才考虑它。

## 10. 集合：Array、Dictionary 和 Set

### 10.1 Array

数组有顺序，并允许重复：

```swift
var words: [String] = ["language", "study"]
words.append("book")

print(words[0]) // language
print(words.count) // 3
```

直接访问不存在的下标会崩溃。更安全的方式是先检查范围，或通过循环处理元素。

常见转换：

```swift
let uppercased = words.map { word in
    word.uppercased()
}

let longWords = words.filter { word in
    word.count >= 5
}
```

- `map`：把每个元素转换成新元素。
- `filter`：只保留符合条件的元素。

### 10.2 Dictionary

字典通过键查找值：

```swift
var hoursByLanguage: [LanguageSpace: Double] = [
    .english: 12.5,
    .japanese: 8.0
]

hoursByLanguage[.english] = 13.0
let hours = hoursByLanguage[.japanese] // Double?
```

字典查询返回 Optional，因为请求的键可能不存在。

### 10.3 Set

集合无重复元素，适合表达唯一值：

```swift
let firstDates: Set<String> = ["2026-08-18", "2026-08-19"]
let secondDates: Set<String> = ["2026-08-19", "2026-08-20"]

let allDates = firstDates.union(secondDates)
```

单词是否跨多个模板文档日期出现，本质上就很适合用“唯一日期集合”的思维理解。

## 11. 闭包

闭包是一段可以被保存、传递并稍后执行的代码。它与其他语言中的 lambda 很接近。

```swift
let announce: (String) -> Void = { language in
    print("进入\(language)学习空间")
}

announce("英语")
```

`(String) -> Void` 表示：接收一个字符串，不返回有意义的值。`Void` 可以理解为“没有返回结果”。

函数也可以接收闭包：

```swift
func performTwice(action: () -> Void) {
    action()
    action()
}

performTwice {
    print("执行")
}
```

最后一个参数是闭包时，可以把它写在圆括号外，这叫尾随闭包。SwiftUI 的 `Button` 和 `ForEach` 大量使用这种语法。

项目中的 `LanguageLauncher` 接收：

```swift
let openLanguage: (LanguageSpace) -> Void
```

它只知道“点击后把语言交出去”，并不知道根路由具体如何变化。真正的跳转由上层 `ContentView` 提供。这样子视图保持单一职责。

## 12. 协议

协议描述一个类型必须提供什么能力，不规定它必须如何实现：

```swift
import Foundation

protocol HoursFormatting {
    func text(for seconds: Double) -> String
}

struct OneDecimalHoursFormatter: HoursFormatting {
    func text(for seconds: Double) -> String {
        String(format: "%.1f 小时", seconds / 3_600.0)
    }
}
```

`OneDecimalHoursFormatter` 遵守 `HoursFormatting`，所以必须实现 `text(for:)`。

协议的价值是替换实现。例如项目把答题音效抽象为协议：正式应用播放音频，UI 测试传入静音播放器。页面只依赖“能够播放音效”这个能力，不依赖 AVAudioPlayer 的细节。

常见协议：

- `View`：提供 `body`。
- `Identifiable`：提供 `id`。
- `CaseIterable`：枚举能够提供 `allCases`。
- `Equatable`：值可以用 `==` 比较。
- `Hashable`：值可以作为 Set 元素或 Dictionary 键。

## 13. 访问控制和常见关键字

```swift
import Foundation

final class ThemeStore {
    static let storageKey = "appAppearance"

    private(set) var mode = ThemeMode.dark
    private let defaults = UserDefaults.standard

    func toggle() {
        mode = mode == .dark ? .light : .dark
    }
}
```

- `private`：只能在当前声明范围内访问。
- `private(set)`：外部可以读取，但只有类型内部可以修改。
- `static`：属于类型本身，不属于某个实例；使用 `ThemeStore.storageKey` 访问。
- `final`：类不能被继承。
- 三元表达式 `条件 ? 值A : 值B`：条件为真取 A，否则取 B。

把 setter 收紧是维护不变量的重要方式。比如累计时长不应该暴露任意修改入口，而应只由计时控制器增加。

## 14. 错误处理

可恢复失败通常用 `throws` 表达：

```swift
enum ImportError: Error {
    case emptyDocument
    case invalidFormat
}

func parse(_ text: String) throws -> [String] {
    guard !text.isEmpty else {
        throw ImportError.emptyDocument
    }
    return text.components(separatedBy: "\n")
}
```

调用时用 `do/catch`：

```swift
do {
    let lines = try parse("language｜｜      语言")
    print(lines)
} catch ImportError.emptyDocument {
    print("文档为空")
} catch {
    print("解析失败：\(error.localizedDescription)")
}
```

- `throws`：函数可能抛出错误。
- `throw`：终止当前正常流程并交出一个错误。
- `try`：明确标记调用可能失败。
- `catch`：接住错误并决定如何反馈。

用户输入、文件读取和数据库写入都可能合理失败，因此 Egangnal 的导入流程会返回可理解错误，而不是使用 `precondition` 让应用崩溃。

## 15. 并发先认识两个概念

初学阶段不需要立刻掌握完整 Swift Concurrency，但应认识：

```swift
@MainActor
final class PageStore {
    var title = "单词本"
}
```

`@MainActor` 表示这个类型的状态属于主执行器。界面状态应在主执行器读写，避免多个执行线程同时修改导致竞态。

另一个常见组合是：

```swift
import Foundation

func loadData() async throws -> String {
    // 教学示例：实际实现可能读取文件或网络。
    "完成"
}

Task {
    do {
        let result = try await loadData()
        print(result)
    } catch {
        print("加载失败：\(error.localizedDescription)")
    }
}
```

- `async`：函数可能异步暂停。
- `await`：等待异步结果，但不是阻塞整个系统线程。
- `Task`：创建异步任务环境。

当前教程不深入 actor、任务取消和 `Sendable`。Egangnal 的计时和文件流程涉及这些边界，适合掌握基础后结合测试再读。

---

下面开始进入 SwiftUI。前面的 Swift 语法仍然全部有效；SwiftUI 只是建立在它之上的界面框架。

## 16. 第一个 SwiftUI View

```swift
import SwiftUI

struct LanguageTitleView: View {
    var body: some View {
        Text("英语学习空间")
    }
}
```

### 16.1 `View` 是协议

`LanguageTitleView: View` 表示结构体遵守 `View` 协议。协议要求它提供 `body`。

### 16.2 `body` 是计算属性

```swift
var body: some View
```

- `var`：计算属性必须用 `var` 声明。
- `body`：SwiftUI 规定的属性名。
- `some View`：返回某一种遵守 `View` 的具体类型，但对调用者隐藏精确的长类型名。

`some` 叫不透明返回类型。你只需知道 `body` 最终返回一个确定的 View 类型，不必手写 SwiftUI 组合后非常长的泛型类型。

### 16.3 View 是描述，不是手工刷新命令

在 SwiftUI 中，我们通常不写“找到某个标签，再把文字改掉”。我们描述：

```swift
Text(isStudying ? "正在学习" : "尚未开始")
```

当 `isStudying` 变化时，SwiftUI 重新计算 `body`，比较新旧描述，并只更新真正需要变化的界面部分。这叫声明式 UI。

## 17. 修饰器和调用顺序

```swift
Text("单词本")
    .font(.title)
    .foregroundStyle(.blue)
    .padding(12)
    .background(.yellow)
```

每一个点开头的调用都是修饰器。修饰器不会在原 View 上原地修改，而是返回一个包裹后的新 View。

调用顺序会影响结果：

```swift
Text("单词本")
    .padding(12)
    .background(.yellow)
```

黄色背景包含 12 点内边距。

```swift
Text("单词本")
    .background(.yellow)
    .padding(12)
```

黄色背景只包住文字，然后外部再增加透明间距。

把修饰器理解为从上到下逐层包装，会比死记效果更可靠。

## 18. 布局：VStack、HStack、ZStack

### 18.1 垂直排列

```swift
VStack(alignment: .leading, spacing: 8) {
    Text("英语")
        .font(.title)
    Text("English")
        .foregroundStyle(.secondary)
}
```

- `VStack`：子视图从上到下排列。
- `alignment: .leading`：子视图沿左边对齐。
- `spacing: 8`：相邻子视图间距为 8 点。
- 花括号里可以放多个 View，这是 SwiftUI 的 ViewBuilder 语法。

### 18.2 水平排列

```swift
HStack(spacing: 16) {
    Text("英语")
    Text("日语")
}
```

`HStack` 从左到右排列。项目首页的两个语言入口就使用了这种基本结构。

### 18.3 层叠排列

```swift
ZStack {
    Color.blue.opacity(0.1)
    Text("英语")
}
```

`ZStack` 按前后层叠放子视图，后写的内容显示在更上方。卡片背景图、渐变和文字经常使用它。

### 18.4 `Spacer`

```swift
HStack {
    Text("单词本")
    Spacer()
    Button("导入") {}
}
```

`Spacer` 尽可能占据可用空间，把左侧标题和右侧按钮推向两端。

### 18.5 `frame`、`padding` 和响应式布局

```swift
Text("英语")
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
```

- `frame(maxWidth: .infinity)`：允许 View 使用父级提供的最大宽度。
- `alignment: .leading`：内容在这个宽度内靠左。
- `padding(20)`：四周增加 20 点内边距。

不要把 `frame(width:)` 用在所有控件上。固定尺寸适合图标按钮和明确规格的卡片；内容区通常使用 `minWidth`、`maxWidth`、布局优先级或 GeometryReader 适配窗口。

## 19. Button 和交互闭包

最简单的按钮：

```swift
Button("进入英语空间") {
    print("点击了英语")
}
```

自定义内容的写法：

```swift
Button {
    print("进入英语")
} label: {
    HStack {
        Text("英语")
        Text("English")
            .foregroundStyle(.secondary)
    }
}
.buttonStyle(.plain)
```

第一个闭包是点击动作，`label` 闭包负责按钮长什么样。`.buttonStyle(.plain)` 去掉默认按钮外观，项目中的语言卡片和图标按钮常用它，再由项目主题自行绘制背景和边框。

适当增加辅助功能：

```swift
.help("进入英语学习空间")
.accessibilityLabel("进入英语学习空间")
.accessibilityIdentifier("dashboard.open.english")
```

- `help`：鼠标停留时显示提示。
- `accessibilityLabel`：VoiceOver 朗读的语义。
- `accessibilityIdentifier`：主要供 UI 自动化稳定定位，不应依赖会变化的显示文字。

## 20. `@State`：View 自己拥有的临时状态

```swift
struct CounterView: View {
    @State private var count = 0

    var body: some View {
        VStack {
            Text("点击次数：\(count)")
            Button("增加") {
                count += 1
            }
        }
    }
}
```

普通 SwiftUI View 是结构体，但不能通过简单的存储属性修改来长期保存界面状态。`@State` 把状态交给 SwiftUI 管理；即使 View 描述被重新创建，状态仍能在该视图身份下保留。

适合 `@State` 的内容：

- 按钮是否展开；
- 当前选择的分页；
- 临时输入文字；
- 鼠标当前悬停哪个卡片；
- 只属于当前页面、离开后可以丢弃的状态。

真实项目中 `CalendarPanel` 使用 `@State` 保存挂历是否展开和当前月份，`LanguageLauncher` 使用 `@State` 保存悬停语言。

不要把需要跨页面共享、需要复杂业务约束或需要持久化的数据全部塞进 `@State`。那类状态更适合 Store 或 Repository。

## 21. 条件界面

```swift
struct StatusView: View {
    @State private var isExpanded = false

    var body: some View {
        VStack {
            Button(isExpanded ? "收起" : "展开") {
                isExpanded.toggle()
            }

            if isExpanded {
                Text("这里是展开内容")
            }
        }
    }
}
```

`toggle()` 会把 Bool 从 `false` 变成 `true`，或从 `true` 变成 `false`。

SwiftUI 的 ViewBuilder 允许在 `body` 中使用 `if`、`if let` 和 `switch` 决定显示的界面。状态变化后，SwiftUI 会插入或移除对应内容。

## 22. `ForEach`：根据数据生成界面

有了前面的 `LanguageSpace` 枚举，可以生成两个按钮：

```swift
struct LanguageButtons: View {
    let openLanguage: (LanguageSpace) -> Void

    var body: some View {
        HStack(spacing: 16) {
            ForEach(LanguageSpace.allCases) { space in
                Button(space.title) {
                    openLanguage(space)
                }
            }
        }
    }
}
```

逐项解释：

- `LanguageSpace.allCases` 来自 `CaseIterable`。
- `ForEach` 为每个 `space` 生成一份按钮描述。
- `LanguageSpace` 遵守 `Identifiable`，因此 `ForEach` 知道每个按钮对应哪个稳定元素。
- 点击后调用上层传入的 `openLanguage` 闭包。

如果数据没有遵守 `Identifiable`，可以显式指定 ID：

```swift
ForEach(["英语", "日语"], id: \.self) { title in
    Text(title)
}
```

`\.self` 是 Key Path，表示用元素自身作为身份。只有元素本身稳定且唯一时才适合这样做。

## 23. Binding：让父子视图共同操作一份状态

### 23.1 父视图拥有状态

```swift
struct ParentView: View {
    @State private var selectedSpace = LanguageSpace.english

    var body: some View {
        LanguagePicker(selection: $selectedSpace)
    }
}
```

`selectedSpace` 由父视图拥有。`$selectedSpace` 不是值本身，而是指向该状态的 Binding。

### 23.2 子视图接收 Binding

```swift
struct LanguagePicker: View {
    @Binding var selection: LanguageSpace

    var body: some View {
        HStack {
            ForEach(LanguageSpace.allCases) { space in
                Button(space.title) {
                    selection = space
                }
            }
        }
    }
}
```

- `@Binding` 表示子视图不拥有这份数据。
- 子视图修改 `selection`，实际修改的是父视图的 `selectedSpace`。
- `$` 取得属性包装器提供的投影值，在这里就是 `Binding<LanguageSpace>`。

可以把 Binding 理解为“受控的双向通道”。它适合父子之间共享一项简单可变值，不等于全局状态管理。

## 24. `@Observable`：把复杂状态放进 Store

真实项目的 [`AppearanceStore.swift`](../Egangnal/Stores/AppearanceStore.swift) 使用 Observation。下面是教学简化版：

```swift
import Observation

@MainActor
@Observable
final class LearningStore {
    private(set) var selectedSpace = LanguageSpace.english
    private(set) var visitCount = 0

    func open(_ space: LanguageSpace) {
        selectedSpace = space
        visitCount += 1
    }
}
```

逐项解释：

- `@Observable`：让属性读取可以被 SwiftUI 跟踪。
- `@MainActor`：Store 的界面状态在主执行器访问。
- `private(set)`：页面能读，但不能绕过方法随意修改。
- `open(_:)`：把相关状态变更收进一个明确动作。

View 使用 Store：

```swift
struct LearningView: View {
    let store: LearningStore

    var body: some View {
        VStack {
            Text("当前：\(store.selectedSpace.title)")
            Text("进入次数：\(store.visitCount)")

            ForEach(LanguageSpace.allCases) { space in
                Button(space.title) {
                    store.open(space)
                }
            }
        }
    }
}
```

`body` 读取了 `selectedSpace` 和 `visitCount`。它们变化时，相关界面会重新计算。

这里的 `let store` 表示 Store 由更上层创建、持有并注入当前 View。若某个 View 自己创建 Store，并要求对象在该 View 的重复重建中保持身份，应写成 `@State private var store = LearningStore()`；不要在 `body` 中临时创建 Store。

### 24.1 `@State` 和 `@Observable` 怎么选

| 情况 | 推荐 |
| --- | --- |
| 单个页面的展开、悬停、临时输入 | `@State` |
| 多项状态共同构成业务流程 | `@Observable` Store |
| 状态需要被多个页面共享 | 上层持有 Store 并传入 |
| 需要保存到磁盘 | Store 调用 Repository 或偏好服务 |

### 24.2 `@Bindable` 是什么

如果需要从一个 `@Observable` 对象的可写属性生成控件要求的 Binding，可以在 View 中使用：

```swift
import Observation
import SwiftUI

@Observable
final class NicknameStore {
    var nickname = ""
}

struct NicknameEditor: View {
    @Bindable var store: NicknameStore

    var body: some View {
        TextField("昵称", text: $store.nickname)
    }
}
```

`@Observable` 让对象可被观察，`@Bindable` 则从对象的可写属性生成 `$store.nickname` 这样的 Binding。项目更倾向让复杂业务状态通过 Store 方法修改，而不是开放所有 setter；文本输入等直接编辑场景才更适合 Binding。初学时先理解 `@State`、`@Binding` 和 `@Observable` 的所有权差异，再使用 `@Bindable`。

## 25. Environment：向一棵界面树传递共享值

Egangnal 的每个页面都需要读取当前调色板和个性化设置，但如果每层 View 都手工转交这些参数，会很繁琐。SwiftUI Environment 提供向下传递共享值的机制。

读取系统环境值：

```swift
struct AdaptiveText: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(colorScheme == .dark ? "深色" : "浅色")
    }
}
```

上层注入：

```swift
AdaptiveText()
    .environment(\.colorScheme, .dark)
```

项目还在 [`AppPersonalization.swift`](../Egangnal/Domain/AppPersonalization.swift) 中定义了自有环境值：

```swift
struct AppPersonalization: Equatable, Sendable {
    let showsLanguageCardArtwork: Bool
    let showsGridBackground: Bool
}
```

`ContentView` 注入它，子页面用 `@Environment(\.appPersonalization)` 读取。

Environment 适合：

- 调色板、字体缩放、系统外观等横切界面信息；
- 一棵视图树中大量后代都需要的只读配置。

它不应成为隐藏所有依赖的万能容器。重要业务服务仍应通过初始化器显式传入，这样依赖更容易发现和测试。

## 26. 页面路由：用枚举表达当前页面

教学简化版路由：

```swift
enum SimpleRoute {
    case dashboard
    case workspace(LanguageSpace)
}
```

`.workspace(LanguageSpace)` 带有关联值，表示工作区页面还必须知道属于哪门语言。

```swift
struct RootView: View {
    @State private var route = SimpleRoute.dashboard

    var body: some View {
        switch route {
        case .dashboard:
            LanguageButtons { space in
                route = .workspace(space)
            }
        case let .workspace(space):
            VStack {
                Text("\(space.title)学习空间")
                Button("返回") {
                    route = .dashboard
                }
            }
        }
    }
}
```

`case let .workspace(space)` 把关联值取出并命名为 `space`。

真实项目的 `AppRoute` 还包含设置页和工作区功能：

```text
.dashboard
.settings
.workspace(语言, 功能)
```

`ContentView` 通过一个 `switch` 组合根页面。这种方式让“当前只能处于一个根页面”成为类型约束，比 `showDashboard`、`showSettings`、`showWorkspace` 三个可能互相矛盾的 Bool 更可靠。

## 27. 生命周期修饰器

```swift
Text("学习空间")
    .onAppear {
        print("页面出现")
    }
    .onDisappear {
        print("页面离开")
    }
```

监听值变化：

```swift
.onChange(of: selectedSpace) { oldValue, newValue in
    print("从 \(oldValue.title) 切换到 \(newValue.title)")
}
```

接收系统通知。下面是 macOS 页面代码片段，所在文件顶部需要同时导入 `SwiftUI` 和 `AppKit`：

```swift
import SwiftUI
import AppKit
```

然后把通知修饰器放在某个 View 的修饰器链中：

```swift
.onReceive(
    NotificationCenter.default.publisher(
        for: NSApplication.willResignActiveNotification
    )
) { _ in
    print("应用即将失去活动状态")
}
```

Egangnal 的 `ContentView` 会监听路由、应用前后台、系统睡眠和退出事件，并交给唯一的 `StudyTimeController`。这里有一个重要设计区别：生命周期修饰器负责报告“发生了什么”，计时规则和持久化不直接写在 View 中。

## 28. `@ViewBuilder` 和拆分子视图

一个 View 变大后，应拆成命名清楚的子视图或私有计算属性：

```swift
struct WorkspaceView: View {
    let space: LanguageSpace

    var body: some View {
        VStack {
            header
            content
        }
    }

    private var header: some View {
        Text(space.title)
            .font(.title)
    }

    @ViewBuilder
    private var content: some View {
        if space == .english {
            Text("English")
        } else {
            Text("日本語")
        }
    }
}
```

`@ViewBuilder` 允许属性或函数内部根据条件组合不同 View。它不是业务层的通用控制流工具，只应用于构建界面。

拆分标准不是“每五行拆一次”，而是某一块是否有独立名称、输入和职责。Egangnal 将单词刷页面协调放在 `WordQuizView`，把具体题型与反馈控件拆到 `WordQuizComponents`，就是按职责拆分。

## 29. 动画基础

最容易理解的状态动画：

```swift
struct ExpandableCircle: View {
    @State private var isExpanded = false

    var body: some View {
        Circle()
            .fill(.blue)
            .frame(
                width: isExpanded ? 160 : 60,
                height: isExpanded ? 160 : 60
            )
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }
    }
}
```

`withAnimation` 告诉 SwiftUI：闭包内的状态变化应以指定动画呈现。

也可以把动画绑定到某个值：

```swift
.animation(.easeOut(duration: 0.15), value: isHovered)
```

只有 `isHovered` 变化时，相关可动画属性才执行动画。

Egangnal 的主题波纹和品牌文字重排比这个例子复杂得多，因为它们需要稳定布局、截图、标题栏同步和减少动态效果支持。应先熟悉普通状态动画，再阅读那些文件。

## 30. 应用入口：`@main`、App 和 Scene

简化的 macOS 应用入口：

```swift
import SwiftUI

@main
struct TutorialApp: App {
    var body: some Scene {
        WindowGroup {
            TutorialRootView()
        }
    }
}
```

- `@main`：告诉编译器程序从这里启动。
- `App`：SwiftUI 应用协议。
- `body: some Scene`：应用提供窗口、菜单等场景，而不是普通 View。
- `WindowGroup`：创建由 SwiftUI 管理的窗口组。
- `TutorialRootView`：窗口内容的根 View，将在第 32 节完成。

真实项目使用：

```swift
Window("Egangnal", id: "main") {
    ContentView(...)
}
```

并在外部加上窗口尺寸、隐藏标题栏、SwiftData 容器和菜单命令。`AppDependencies.live()` 在入口创建一次全局依赖，避免每次 View 刷新时重新创建数据库或 Store。

## 31. Preview：不启动完整应用也能看 View

```swift
#Preview {
    LanguageTitleView()
        .frame(width: 400, height: 240)
}
```

Preview 用于快速查看单个 View。需要依赖的页面，应提供不会触碰真实数据的预览实现：

```swift
#Preview {
    LearningView(store: LearningStore())
}
```

Egangnal 为多个 Store 和 Repository 提供 `.preview` 或 Preview 假实现。预览不应写入用户正式数据库，也不应真的检查更新或播放声音。

## 32. 贯穿练习：做一个简化语言空间选择器

下面把前面的知识组合成一个小练习。它不包含数据库和计时，只练习类型、状态、列表、父子通信与页面切换。

运行方式有两种，必须选择其一：

- 在 Xcode 新建独立的 macOS App 教学项目：使用本节最后提供的 `TutorialApp` 作为唯一 `@main` 入口，即可独立运行。
- 把练习临时放入 Egangnal target：只使用 `#Preview` 查看 `TutorialRootView`，不要再声明第二个 `@main`，否则一个 target 会出现两个应用入口。

### 32.1 第一步：定义语言数据

新建 `TutorialLanguageSpace.swift`：

```swift
enum TutorialLanguageSpace: String, CaseIterable, Identifiable {
    case english
    case japanese

    var id: Self { self }

    var title: String {
        switch self {
        case .english:
            "英语"
        case .japanese:
            "日语"
        }
    }

    var nativeTitle: String {
        switch self {
        case .english:
            "English"
        case .japanese:
            "日本語"
        }
    }
}
```

这一层只有数据含义，不导入 SwiftUI。它可以在界面之外单独测试。

### 32.2 第二步：做一张语言卡片

```swift
import SwiftUI

struct TutorialLanguageCard: View {
    let space: TutorialLanguageSpace
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(space.title)
                    .font(.title2.bold())

                Text(space.nativeTitle)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(.quaternary, in: .rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .help("进入\(space.title)学习空间")
    }
}
```

输入只有两个：

- `space` 决定显示哪门语言；
- `action` 决定点击后做什么。

卡片不拥有路由，也不知道其他页面。这种设计让组件更容易复用和预览。

### 32.3 第三步：创建首页

```swift
import SwiftUI

struct TutorialDashboardView: View {
    let openLanguage: (TutorialLanguageSpace) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Egangnal")
                .font(.system(size: 40, weight: .semibold))

            HStack(spacing: 16) {
                ForEach(TutorialLanguageSpace.allCases) { space in
                    TutorialLanguageCard(space: space) {
                        openLanguage(space)
                    }
                }
            }
        }
        .padding(40)
    }
}
```

这里出现了两层闭包：

1. `ForEach` 的闭包收到当前 `space`，并返回一张卡片；
2. 卡片的点击闭包调用 `openLanguage(space)`，把选择交给上层。

### 32.4 第四步：创建功能页

```swift
import SwiftUI

struct TutorialWorkspaceView: View {
    let space: TutorialLanguageSpace
    let goBack: () -> Void

    @State private var showsNativeTitle = true

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .help("返回首页")

                Spacer()
            }

            Spacer()

            Text(space.title)
                .font(.largeTitle.bold())

            if showsNativeTitle {
                Text(space.nativeTitle)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            Toggle("显示原文名称", isOn: $showsNativeTitle)
                .frame(width: 180)

            Spacer()
        }
        .padding(40)
    }
}
```

这个页面展示了：

- 用 SF Symbols 的 `chevron.left` 作为熟悉的返回图标；
- `Spacer` 把核心内容推到纵向中间；
- `@State` 保存只属于本页的显示开关；
- `$showsNativeTitle` 把 Binding 传给 Toggle；
- `if` 根据状态插入或移除原文标题。

### 32.5 第五步：用路由连接页面

```swift
import SwiftUI

private enum TutorialRoute {
    case dashboard
    case workspace(TutorialLanguageSpace)
}

struct TutorialRootView: View {
    @State private var route = TutorialRoute.dashboard

    var body: some View {
        switch route {
        case .dashboard:
            TutorialDashboardView { space in
                route = .workspace(space)
            }

        case let .workspace(space):
            TutorialWorkspaceView(space: space) {
                route = .dashboard
            }
        }
    }
}

#Preview {
    TutorialRootView()
        .frame(width: 820, height: 560)
}
```

如果这是一个独立教学项目，把 Xcode 自动生成的 App 入口替换为：

```swift
import SwiftUI

@main
struct TutorialApp: App {
    var body: some Scene {
        WindowGroup {
            TutorialRootView()
        }
    }
}
```

如果练习代码位于 Egangnal target，请保留项目原来的 `EgangnalApp`，不要添加上面这段第二入口。

到这里已经形成最小闭环：

```text
根 View 持有路由
    ↓
首页把点击事件上报
    ↓
根 View 修改路由
    ↓
SwiftUI 重新计算 body
    ↓
显示对应语言的功能页
    ↓
返回动作再次修改路由
```

这与 Egangnal 真实导航骨架的思想相同，只是正式项目还多了设置页、具体功能、上次功能恢复、计时同步和离开协调。

## 33. 从练习映射回真实项目

| 教学概念 | 教学代码 | 真实项目位置 |
| --- | --- | --- |
| 语言枚举 | `TutorialLanguageSpace` | `Domain/LanguageSpace.swift` |
| 首页语言按钮 | `TutorialLanguageCard` | `Features/Dashboard/LanguageLauncher.swift` |
| 根路由 | `TutorialRoute` | `App/AppRoute.swift` |
| 根据路由组合页面 | `TutorialRootView` | `ContentView.swift` |
| 功能页共同容器 | `TutorialWorkspaceView` | `Features/LanguageSpace/WorkspaceShell.swift` |
| 页面临时状态 | `showsNativeTitle` | 各 Feature 中的 `@State` |
| 应用级状态 | 尚未加入练习 | `Stores` 下的 `@Observable` 类型 |
| 依赖创建 | 尚未加入练习 | `App/AppDependencies.swift` |
| 应用入口 | `TutorialApp` | `EgangnalApp.swift` |

建议实际跟读时，先比较教学版和真实 `LanguageSpace`，再比较 `TutorialDashboardView` 与 `LanguageLauncher`。真实代码多出来的 Environment、悬停、响应式宽度、辅助功能和项目调色板，都是在同一基础上逐步添加的。

## 34. SwiftData 只做入门认识

SwiftData 用 Swift 类型描述本地持久化模型。最小示意：

```swift
import Foundation
import SwiftData

@Model
final class SimpleWord {
    var term: String
    var meaning: String

    init(term: String, meaning: String) {
        self.term = term
        self.meaning = meaning
    }
}
```

- `@Model`：告诉 SwiftData 这个类需要持久化。
- 模型使用类，因此对象拥有可跟踪身份。
- 初始化器确保创建词条时提供单词和词义。

应用需要 `ModelContainer`，写入通常通过 `ModelContext`。文件和数据库操作都可能失败，因此下面把创建、插入和保存放进 `do/catch`：

```swift
@MainActor
func saveExampleWord() {
    do {
        let container = try ModelContainer(for: SimpleWord.self)
        let context = ModelContext(container)
        let word = SimpleWord(term: "language", meaning: "语言")
        context.insert(word)
        try context.save()
    } catch {
        print("保存失败：\(error.localizedDescription)")
    }
}
```

教程到这里先停止继续深入。真实 Egangnal 没有让 View 直接执行这些代码，而是通过 `WordBookRepository`：

```text
View 提交“导入单词”意图
    ↓
解析器先校验整份文档
    ↓
Repository 负责 SwiftData 查询和写入
    ↓
View 只接收适合显示的 Snapshot
```

这样才能正确处理首次释义、跨日期去重、事务回滚和语言隔离。初学时可以用简单模型练习 CRUD，但不要把简单示例直接替换进真实仓储。

## 35. UserDefaults：保存小型偏好

主题选择不需要复杂数据库，可以使用 UserDefaults：

```swift
import Foundation

let key = "tutorialTheme"

UserDefaults.standard.set("dark", forKey: key)
let savedValue = UserDefaults.standard.string(forKey: key)
```

UserDefaults 适合少量设置，不适合大量词条或复杂查询。

项目的 `AppearanceStore` 还通过协议包住 UserDefaults：

```swift
protocol AppearancePreferences: AnyObject {
    func string(forKey defaultName: String) -> String?
    func set(_ value: Any?, forKey defaultName: String)
}
```

正式环境传 `UserDefaults.standard`，测试可以传内存假对象。这体现了协议带来的可替换性。

## 36. 最小单元测试

项目使用 Swift Testing。先测试不依赖界面的纯逻辑：

```swift
import Testing
@testable import Egangnal

@Test("语言空间提供正确中文名称")
func languageTitle() {
    #expect(TutorialLanguageSpace.english.title == "英语")
    #expect(TutorialLanguageSpace.japanese.title == "日语")
}
```

`@testable import Egangnal` 让测试 target 看见应用模块中的内部声明。如果你在独立教学项目中练习，应把 `Egangnal` 改成那个项目的 Product Module Name；如果类型直接写在同一个脚本或 Playground 中，则不需要这行导入。

- `@Test`：声明测试。
- 括号中的中文是测试名称。
- `#expect`：验证条件应该为真。

测试枚举完整数量：

```swift
@Test("首版只有两个语言空间")
func languageCount() {
    #expect(TutorialLanguageSpace.allCases.count == 2)
}
```

一个好的入门顺序是先测 Domain，再测 Store，最后只为关键用户路径写 UI 自动化。业务规则如果只能启动整个窗口后测试，通常说明规则和 View 耦合得太紧。

## 37. SwiftUI 中常见的初学错误

### 37.1 在 `body` 中做副作用

错误思路：

```swift
var body: some View {
    saveToDatabase() // 不要这样做
    return Text("完成")
}
```

`body` 可能被多次计算，不能假定只执行一次。保存、播放音效、发起导入等副作用应由 Button、任务、生命周期回调或 Store 方法触发。

### 37.2 把可变化值声明成普通属性

```swift
struct WrongView: View {
    var count = 0

    var body: some View {
        Button("增加") {
            count += 1 // View 是值类型，这里不能这样持有界面状态
        }
    }
}
```

页面自己的可变状态应使用 `@State`，复杂共享状态应由可观察 Store 持有。

### 37.3 同时用多个 Bool 表示互斥页面

```swift
var showsDashboard = true
var showsSettings = true
```

这会产生两个页面同时为真的非法状态。使用 `enum Route`，让当前页面只能是一个 case。

### 37.4 随处直接写数据库

如果多个 View 分别查询和修改 SwiftData，去重、错误回滚和测试会越来越难。真实项目把持久化集中在 Repository，并让 View 处理用户意图和展示状态。

### 37.5 把 `onAppear` 当成只调用一次

View 进入界面树时可能多次触发 `onAppear`。需要幂等的操作必须自己保证不会重复产生副作用。Egangnal 的计时控制器需要处理重复激活、乱序睡眠通知等情况，不能只依赖页面“看起来只出现一次”。

### 37.6 用数组下标当作不稳定列表身份

列表顺序变化时，下标可能对应另一个元素，导致动画或编辑状态错位。业务对象应提供稳定 ID；品牌重排动画甚至为重复字母保留稳定源索引。

### 37.7 忽略修饰器顺序

`.padding().background()` 和 `.background().padding()` 不是同一效果。遇到尺寸不符合预期时，从上到下检查每一层 View 如何被包装。

### 37.8 强制解包 Optional

`value!` 不是“帮我取出值”，而是“我保证它绝不为 nil，否则崩溃”。用户文件、日期解析和数据库查询都可能没有结果，应使用 `if let`、`guard let` 或抛出错误。

## 38. 如何调试布局和状态

### 38.1 先缩小问题范围

把复杂页面拆成一个 Preview，只保留出现问题的控件和固定示例数据。确认是布局问题、状态问题还是持久化问题。

### 38.2 检查状态所有者

问三个问题：

1. 谁创建这份状态？
2. 谁允许修改它？
3. 离开页面后它是否应该保留？

如果答案是“页面自己创建，只有页面修改，离开可丢弃”，用 `@State`。如果多项业务状态需要统一约束，放进 Store。需要保存时，再由 Store 调用仓储或偏好服务。

### 38.3 用辅助背景看尺寸

调试时可以临时使用：

```swift
someView
    .background(.red.opacity(0.15))
    .border(.red)
```

确认实际 frame 后再移除。不要把调试颜色提交为正式主题。

### 38.4 给异步和错误状态明确展示

页面至少要能区分：初始、加载中、成功、空数据和失败。不要让失败与“没有内容”看起来完全一样。

## 39. 阅读真实源码的推荐路线

### 第一阶段：只看 Swift 基础

1. `Domain/LanguageSpace.swift`：枚举、switch、计算属性。
2. `Design/AppAppearance.swift`：枚举和 `toggled`。
3. `Domain/CalendarMonth.swift`：结构体、初始化器、Optional、数组和函数。

读完后，尝试自己写一个 `LanguageSpace.description` 计算属性和对应测试。

### 第二阶段：看简单 SwiftUI

1. `Features/Dashboard/AppearanceToggle.swift`：View、Button、Image、修饰器和 Preview。
2. `Features/Dashboard/LanguageLauncher.swift`：HStack、ForEach、闭包、`@State` 和悬停。
3. `Domain/AppPersonalization.swift`：自定义 Environment。

读完后，尝试给教学选择器加一个 `@State` 悬停效果。

### 第三阶段：看状态与路由

1. `Stores/AppearanceStore.swift`：类、协议、UserDefaults、`@Observable`。
2. `App/AppRoute.swift`：带关联值的枚举和 Binding。
3. `ContentView.swift`：switch 路由、Environment、`onAppear`、`onChange`。
4. `EgangnalApp.swift`：`@main`、App、Scene 和依赖注入。

读完后，尝试在教学项目中加入一个设置页路由，但先不要添加持久化。

### 第四阶段：选择一个真实功能

- 想学纯业务逻辑：读 `WordQuizModels` 和 `WordQuizEngine`。
- 想学文件解析：读 `WordBookMarkdown` 及其测试。
- 想学状态协调：读 `WordQuizStore`。
- 想学持久化分层：读 `WordBookRepository`，先看协议，再看实现。

计时状态机、主题快照波纹、品牌字母动画和 Sparkle 更新属于进阶阅读，不建议作为 SwiftUI 入门材料。

## 40. 练习清单

按顺序完成，每一步都保持可运行：

1. 在教学语言枚举中增加 `nativeTitle`，并写两个 `#expect`。
2. 用 `ForEach` 显示两个语言按钮。
3. 用 `@State` 显示当前选中的语言。
4. 把按钮拆成 `TutorialLanguageCard`，通过闭包上报点击。
5. 用 `enum TutorialRoute` 在首页和工作区之间切换。
6. 给工作区增加 Toggle，并用 `$` 传递 Binding。
7. 创建 `@Observable` Store，记录进入语言空间的次数。
8. 用 UserDefaults 保存上次选择的语言。
9. 为保存逻辑声明一个协议，并在测试中传入内存实现。
10. 最后对照真实 `WorkspaceNavigationStore`，观察项目如何分别记录两门语言的上次功能。

不要一次把数据库、动画、音频和更新都加进练习。每次只引入一个新概念，先理解数据所有权和状态流，再扩展视觉效果。

## 41. 一张最终心智图

```text
用户点击按钮
    ↓
Button 的 action 闭包
    ↓
修改 @State，或调用 @Observable Store 的方法
    ↓
Store 执行业务规则，必要时调用 Repository
    ↓
状态发生变化
    ↓
SwiftUI 重新计算读取该状态的 body
    ↓
窗口更新必要部分
```

对于 Egangnal，再加上持久化边界：

```text
View              负责显示和上报用户意图
Store/Controller  负责页面状态和用例流程
Domain            负责数据含义与纯规则
Repository        负责 SwiftData 查询、写入和失败处理
AppDependencies   负责创建并连接这些对象
```

掌握这两张图后，再看到一个新文件时，先判断它处于哪一层、拥有哪份状态、依赖由谁创建。这样阅读真实项目会比从语法细节中盲目跳转更有效。

## 42. 下一步

完成教程后，建议实际做一次很小的项目改动，例如只新增一个不持久化的显示设置，并完成以下闭环：

1. 写清需求和状态归属；
2. 修改 Domain 或 Store；
3. 在 View 中展示和触发；
4. 添加最小单元测试；
5. 运行 Debug 构建；
6. 检查深色、浅色和最小窗口；
7. 更新对应文档。

这正是 Egangnal 强调的开发方式：一步一个脚印，每一步都能解释、能测试、能回退，也能成为下一步的可靠基础。

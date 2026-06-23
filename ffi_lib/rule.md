## 规则语法

### 解析模式前缀

| 前缀              | 模式       | 说明                                      |
| ----------------- | ---------- | ----------------------------------------- |
| `@CSS:`           | CSS 选择器 | 明确指定使用 CSS 模式                     |
| `@XPath:`         | XPath      | 明确指定使用 XPath 模式                   |
| `@Json:`          | JsonPath   | 明确指定使用 JsonPath 模式                |
| `@Regex:`         | 正则表达式 | 明确指定使用正则模式                      |
| `@Js:`            | JavaScript | 明确指定使用 JS 模式                      |
| `@@`              | 转义       | 去除前两个字符后按默认模式解析            |
| `/` 开头          | XPath      | 自动识别为 XPath                          |
| `$.` 或 `$[` 开头 | JsonPath   | 自动识别为 JsonPath                       |
| 无前缀            | 默认       | HTML 内容使用 CSS，JSON 内容使用 JsonPath |

### 规则链

使用 `@` 分隔符串联多条规则，前一步的输出作为下一步的输入：

```go
// CSS 链式选择：先选 div.outer，再选 div.inner，再选 span，最后取文本
a.GetString("div.outer@div.inner@span@text")

// 混合模式链：CSS 提取后用 JS 处理
a.GetString("div.title@text@js:result.toUpperCase()")
```

### 规则组合

| 操作符 | 说明             | 示例                                   |
| ------ | ---------------- | -------------------------------------- |
| `&&`   | 合并所有结果     | `//div[1]/text() && //div[2]/text()`   |
| `\|\|` | 取第一个非空结果 | `//div[1]/text() \|\| //div[2]/text()` |
| `%%`   | 按索引交叉合并   | `//a/text() %% //a/@href`              |

### CSS 选择器语法

```go
// 基本选择
a.GetString("div@class")           // 获取 class 属性
a.GetString("div@text")            // 获取文本内容
a.GetString("div@html")            // 获取 HTML 内容
a.GetString("div@ownText")         // 获取元素自身文本（不含子元素）
a.GetString("div@textNodes")       // 获取文本节点列表

// 索引选择
a.GetString("p.2@text")            // 获取第 3 个 p 元素（从 0 开始）
a.GetString("p.-1@text")           // 获取最后一个 p 元素
a.GetString("p[1:3]@text")         // 获取第 1-3 个 p 元素
a.GetString("p!0@text")            // 排除第 1 个 p 元素

// CSS 模式（使用空格分隔选择器）
a.GetString("@CSS:div.content p span@text")
```

### XPath 语法

```go
a.GetString("//div[@class='title']/text()")     // 获取文本
a.GetString("//a/@href")                        // 获取属性
a.GetString("//div[1]//span/text()")             // 带索引的选择
```

### JsonPath 语法

```go
a.GetString("$.store.book[0].title")             // 获取嵌套字段
a.GetStringList("$.store.book[*].title")         // 获取列表
a.GetString("$.data.items[?(@.price > 10)].name") // 过滤查询
```

### 正则替换

使用 `##正则##替换` 语法对结果进行替换：

```go
// 移除所有数字
a.GetString("div@text##\\d+##")

// 将数字替换为 NUM
a.GetString("div@text##\\d+##NUM")

// 只替换第一个匹配（使用三个 #）
a.GetString("div@text##\\d+##NUM###")
```

### 变量存储

```go
ruleData := data.NewRuleData()
a := analyzer.NewAnalyzerWithData(html, "", ruleData)

// 保存变量
ruleData.Put("key", "value")

// 在规则中使用变量
a.GetString("div.@get:{key}@text")
```

### JavaScript 执行

```go
// 使用 @js: 前缀
a.GetString("div@text@js:result.toUpperCase()")

// 使用 <js></js> 标签
a.GetString("div@text<js>result + ' suffix'</js>")
```

## API 文档

### analyzer 包

#### NewAnalyzer

```go
func NewAnalyzer(content interface{}, baseUrl string) *AnalyzeRule
```

创建解析规则实例。`content` 可以是 HTML 字符串或 JSON 字符串。`baseUrl` 用于 URL 解析。

#### NewAnalyzerWithData

```go
func NewAnalyzerWithData(content interface{}, baseUrl string, ruleData data.RuleDataInterface) *AnalyzeRule
```

创建带变量存储的解析规则实例。

#### AnalyzeRule.SetContent

```go
func (a *AnalyzeRule) SetContent(content interface{}, baseUrl string)
```

设置待解析内容，会重置所有解析器实例。

#### AnalyzeRule.GetString

```go
func (a *AnalyzeRule) GetString(rule string) (string, error)
```

获取单个文本结果。如果有多条结果，使用换行符连接。

#### AnalyzeRule.GetStringList

```go
func (a *AnalyzeRule) GetStringList(rule string) ([]string, error)
```

获取文本列表。

#### AnalyzeRule.GetElement

```go
func (a *AnalyzeRule) GetElement(rule string) (interface{}, error)
```

获取单个元素对象。

#### AnalyzeRule.GetElements

```go
func (a *AnalyzeRule) GetElements(rule string) ([]interface{}, error)
```

获取元素列表。

### data 包

#### RuleData

```go
type RuleData struct {
    // 内部使用 sync.RWMutex 保证并发安全
}

func NewRuleData() *RuleData
func (r *RuleData) Put(key, value string)
func (r *RuleData) Get(key string) string
```

线程安全的键值对存储，用于在规则间传递数据。

### parsers 包

#### jsoup.AnalyzeByJSoup

```go
func New(content interface{}) (*AnalyzeByJSoup, error)
func (a *AnalyzeByJSoup) GetString(rule string) (string, error)
func (a *AnalyzeByJSoup) GetStringList(rule string) []string
func (a *AnalyzeByJSoup) GetElements(rule string) []*goquery.Selection
```

CSS 选择器解析器，基于 goquery 库。

#### xpath.AnalyzeByXPath

```go
func New(content interface{}) (*AnalyzeByXPath, error)
func (a *AnalyzeByXPath) GetString(rule string) (string, error)
func (a *AnalyzeByXPath) GetStringList(rule string) []string
func (a *AnalyzeByXPath) GetElements(rule string) []*html.Node
```

XPath 解析器，基于 antchfx/htmlquery 库。

#### jsonpath.AnalyzeByJSonPath

```go
func New(content interface{}) (*AnalyzeByJSonPath, error)
func (a *AnalyzeByJSonPath) GetString(rule string) (string, error)
func (a *AnalyzeByJSonPath) GetStringList(rule string) []string
func (a *AnalyzeByJSonPath) GetObject(rule string) (interface{}, error)
func (a *AnalyzeByJSonPath) GetList(rule string) []interface{}
```

JsonPath 解析器，基于 ohler55/ojg 库。

#### regex 包

```go
func GetElement(content string, regs []string, index int) ([]string, error)
func GetElements(content string, regs []string, index int) ([][]string, error)
func GetElementStr(content string, regs []string, index int) (string, error)
func GetElementsStr(content string, regs []string, index int) ([]string, error)
```

正则解析器，支持多级正则链式匹配。

### ruleanalyzer 包

```go
func New(data string, code bool) *RuleAnalyzer
func (r *RuleAnalyzer) SplitRule(split ...string) []string
func (r *RuleAnalyzer) ChompRuleBalanced(open, close rune) bool
func (r *RuleAnalyzer) ChompCodeBalanced(open, close rune) bool
func (r *RuleAnalyzer) InnerRule(inner string, startStep, endStep int, fr func(string) string) string
func (r *RuleAnalyzer) Trim() string
```

规则字符串分析器，负责智能分割规则字符串，正确处理括号平衡、引号、转义等边界情况。

## 使用示例

### 解析书籍详情页

```go
html := `
<div class="book-info">
    <h1 class="title">仙逆</h1>
    <div class="author">耳根</div>
    <div class="intro">顺为仙，逆为仙...</div>
    <img class="cover" src="/cover.jpg"/>
    <a class="toc" href="/toc">查看目录</a>
</div>`

a := analyzer.NewAnalyzer(html, "http://example.com")

title, _ := a.GetString("h1.title@text")           // 仙逆
author, _ := a.GetString("div.author@text")         // 耳根
intro, _ := a.GetString("div.intro@text")           // 顺为仙，逆为仙...
cover, _ := a.GetString("img.cover@src")            // /cover.jpg
tocUrl, _ := a.GetString("a.toc@href")              // /toc
```

### 解析搜索结果列表

```go
html := `
<div class="results">
    <div class="item"><a href="/b/1">书名1</a><span>作者1</span></div>
    <div class="item"><a href="/b/2">书名2</a><span>作者2</span></div>
    <div class="item"><a href="/b/3">书名3</a><span>作者3</span></div>
</div>`

a := analyzer.NewAnalyzer(html, "")

titles, _ := a.GetStringList("div.item@a@text")     // [书名1, 书名2, 书名3]
authors, _ := a.GetStringList("div.item@span@text") // [作者1, 作者2, 作者3]
urls, _ := a.GetStringList("div.item@a@href")       // [/b/1, /b/2, /b/3]
```

### 解析 JSON API 响应

```go
json := `{
    "data": {
        "books": [
            {"name": "凡人修仙传", "author": "忘语"},
            {"name": "遮天", "author": "辰东"}
        ]
    }
}`

a := analyzer.NewAnalyzer(json, "")

names, _ := a.GetStringList("$.data.books[*].name")  // [凡人修仙传, 遮天]
firstAuthor, _ := a.GetString("$.data.books[0].author") // 忘语
```

### 使用正则替换清理数据

```go
html := `<p>价格：￥128.50元</p>`
a := analyzer.NewAnalyzer(html, "")

// 移除货币符号和单位
price, _ := a.GetString("p@text##[￥元价格：]##")  // 128.50
```

### 使用 JavaScript 处理数据

```go
html := `<p>hello world</p>`
a := analyzer.NewAnalyzer(html, "")

// 转换为大写
result, _ := a.GetString("p@text@js:result.toUpperCase()")  // HELLO WORLD

// 字符串替换
result, _ := a.GetString("p@text@js:result.replace('world', 'golang')")  // hello golang
```

## 
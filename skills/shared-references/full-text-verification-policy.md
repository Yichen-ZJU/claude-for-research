# Full-Text Verification Policy（全文核验统一策略）

本文件是**何时必须读全文、何时只能引用片段/元数据级证据**的唯一权威
定义。`deep-research`、`literature-review`、`researcher`/`verifier`
子代理均以本文件为准；冲突时以本文件为准。最后更新：2026-10-03。

## 证据分级

| 级别 | 定义 | 能支撑什么 |
|---|---|---|
| `full-text` | 论文/文档全文取得并定位到原文段落（通道不限：MCP 或 WebFetch 完整 HTML） | 承重声明（load-bearing claims）、数值复现、方法细节对比 |
| `full-text-web` | 完整、版本固定的官方 HTML（如 arXiv HTML 版）经 WebFetch 取得，原段可定位 | 同 full-text（provenance 标注通道为 web） |
| `fragment` | 摘要、HTML 正文片段、官方文档页、搜索摘要 | 方向性判断、背景叙述、非关键引用 |
| `metadata` | 标题/作者/日期/引用数等书目元数据 | 存在性声明、相关工作枚举 |
| `unverified` | 单次检索未命中或来源冲突 | 什么都不能支撑，只能作为待查线索 |

## 何时必须 full-text

以下结论**不允许**建立在 fragment/metadata 上：

1. 论文/报告的**核心承重结论**（"X 比 Y 好 Z%"之类将被引用的声明）；
2. 任何**数值、数据集规模、评测指标**的具体引用；
3. 方法描述中与你的工作**直接可比**的细节（架构、损失、训练配置）；
4. 反驳或质疑一篇论文的具体主张时。

## 合规的 full-text 获取路径（按优先级）

1. **arxiv MCP**（`download_paper` + `read_paper`/`search_paper_text`）：
   主路径，服务端下载、本地缓存、有界返回。注意
   `arxiv-mcp-server` 的 PDF 支持是**可选依赖**（`[pdf]` extra）——
   `download_paper` 报 PDF 解析/依赖错误即视为本路径不可用。
2. **alphaxiv MCP**（`get_paper_content` / `answer_pdf_queries`）：
   增强路径，尤其适合 PDF 问答与代码仓库。失效特征 401/403/连接错，
   **不重试，直接降级**。
3. **WebFetch 路径**（按内容分级，不按通道惩罚）：
   - **完整、版本固定的官方 HTML**（如 arXiv HTML 版全文）→ `full-text-web`
     级，与 full-text 同级使用，provenance 标注通道为 web；承重声明可
     直接使用，不必标 `unverified-fulltext`。
   - **摘要页/abs 页/搜索摘要** → fragment 级，承重声明仍需升级。
   - **裸 `.pdf` URL 仍禁止 WebFetch**（历史崩溃事故，限制保留不动摇）；
     只有 PDF 版本时引用其 URL 并在 provenance 标注，转走 MCP 全文路径。
   - 证据的资格标准是"来源可靠 + 内容完整 + 版本固定 + 原段可定位"，
     获取通道（MCP / WebFetch）本身不构成降级理由。

## 子代理约束

子代理（researcher/verifier/writer）在本环境通常**没有 MCP 工具**：
子代理只做 fragment/metadata 级证据收集与线索整理；承重声明的
full-text 核查**升级给主代理**用 arxiv MCP 执行。子代理 prompt 里
禁止编造具体 MCP 工具调用指令（canonical set: WebSearch/WebFetch）。

## provenance 记录

每次降级、每条 `unverified-fulltext` 承重声明、每个零结果查询，
都写入 `<slug>.provenance.md`：查询串、来源、日期、证据级别。

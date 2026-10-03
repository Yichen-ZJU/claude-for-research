# natbib 说明

本目录的 LaTeX 模板使用 `\usepackage{natbib}`。natbib 宏包受
[LPPL](https://www.latex-project.org/lppl/)（LaTeX Project Public License）
约束，其条款要求分发 `.sty` 时必须随附原始源文件 `natbib.dtx`。
为遵守该条款，本仓库**不内置** natbib 副本。

编译前请通过 TeX 发行版安装：

```bash
# TeX Live
tlmgr install natbib
# 或 Debian/Ubuntu
sudo apt install texlive-latex-recommended
# MiKTeX: 包管理器搜索 natbib 安装
```

Overleaf 已内置 natbib，无需额外操作。

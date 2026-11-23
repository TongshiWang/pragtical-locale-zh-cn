# pragtical-locale-zh-cn

[Pragtical](https://pragtical.dev/) 文本编辑器的**简体中文界面汉化插件**（`mod-version: 3`）。

## 功能特性

- **菜单与右键菜单汉化**：覆盖顶层菜单（文件、编辑、搜索、视图、工具、帮助）、子菜单及文件树/编辑器右键上下文菜单。
- **核心界面与弹窗汉化**：覆盖欢迎页（EmptyView）、关于页（AboutView）、日志视图（LogView）、状态栏（StatusView）提示、确认框（NagView）、命令面板（CommandView）提示等，同时保留内部英文标识以确保插件命令与配置逻辑稳定运行。
- **设置面板与插件设置汉化**：覆盖 Core 核心设置分组、常用内置插件设置（Treeview、Search UI、Project Search、Line Wrapping、Scale 等）以及下拉选项和默认值提示。
- **插件管理器与动态文本**：支持插件列表排序/筛选标签、查找替换匹配计数等动态字符串的模式化翻译。
- **安全开关**：在 **工具 > 设置… > 插件 > 简体中文汉化 (Locale Zh-CN)** 中可随时开启或关闭（重启生效）。

## 安装方法

### 方式一：PowerShell 一键安装（Windows）

```powershell
git clone https://github.com/TongshiWang/pragtical-locale-zh-cn.git
cd pragtical-locale-zh-cn
.\install.ps1
```

### 方式二：手动安装

将本仓库中的 `plugins/locale_zh_cn` 文件夹复制到 Pragtical 用户配置目录的 `plugins/` 下：

- **Windows (默认安装包)**：`%LOCALAPPDATA%\Programs\Pragtical\user\plugins\locale_zh_cn`
- **Linux / macOS**：`~/.config/pragtical/plugins/locale_zh_cn`

重启 Pragtical 即可生效。

## 目录结构

```text
plugins/locale_zh_cn/
├── init.lua           # 插件入口与 UI Hook 逻辑
├── dict_menu.lua      # 菜单与上下文菜单词典
├── dict_ui.lua        # 视图、弹窗与工具提示词典
└── dict_settings.lua  # 设置面板词典
```

## 许可证

[MIT License](LICENSE)

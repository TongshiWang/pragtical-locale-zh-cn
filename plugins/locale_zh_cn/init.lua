-- mod-version:3 -- priority:-1
local core = require "core"
local common = require "core.common"
local config = require "core.config"
local style = require "core.style"
local MenuView = require "core.menuview"
local ContextMenu = require "core.contextmenu"
local NagView = require "core.nagview"
local CommandView = require "core.commandview"
local StatusView = require "core.statusview"
local LogView = require "core.logview"
local EmptyView = require "core.emptyview"
local Node = require "core.node"
local DocView = require "core.docview"
local ImageView = require "core.imageview"
local AudioView = require "core.audioview"
local MarkdownView = require "core.markdownview"

local Widget = require "widget"
local Button = require "widget.button"
local CheckBox = require "widget.checkbox"
local ColorPickerDialog = require "widget.colorpickerdialog"
local Dialog = require "widget.dialog"
local FilePicker = require "widget.filepicker"
local FoldingBook = require "widget.foldingbook"
local InputDialog = require "widget.inputdialog"
local Label = require "widget.label"
local ListBox = require "widget.listbox"
local MessageBox = require "widget.messagebox"
local NoteBook = require "widget.notebook"
local SelectBox = require "widget.selectbox"
local TextBox = require "widget.textbox"
local Toggle = require "widget.toggle"
local ToggleButton = require "widget.togglebutton"

local function read_saved_settings()
  local ok, data = pcall(dofile, USERDIR .. PATHSEP .. "user_settings.lua")
  if ok and type(data) == "table" and type(data.config) == "table" then
    return data.config
  end
  return nil
end

local saved_settings = read_saved_settings()
local disabled_by_settings = saved_settings
  and type(saved_settings.disabled_plugins) == "table"
  and saved_settings.disabled_plugins.locale_zh_cn == true

config.plugins.locale_zh_cn = common.merge({
  enabled = true,
  config_spec = {
    name = "简体中文汉化 (Locale Zh-CN)",
    {
      label = "启用简体中文界面",
      description = "开启或关闭 Pragtical 界面简体中文汉化（修改后需重启编辑器生效）。",
      path = "enabled",
      type = "toggle",
      default = true
    }
  }
}, config.plugins.locale_zh_cn)

local saved_enabled = true
if saved_settings
  and type(saved_settings.plugins) == "table"
  and type(saved_settings.plugins.locale_zh_cn) == "table"
  and saved_settings.plugins.locale_zh_cn.enabled == false
then
  saved_enabled = false
end

local M = {
  dict = {},
  enabled = not disabled_by_settings
    and saved_enabled
    and config.plugins.locale_zh_cn.enabled ~= false
}

local DICT = M.dict

local function merge_dict(modname)
  local ok, tbl = pcall(require, modname)
  if ok and type(tbl) == "table" then
    for k, v in pairs(tbl) do
      DICT[k] = v
    end
  end
end

merge_dict("plugins.locale_zh_cn.dict_menu")
merge_dict("plugins.locale_zh_cn.dict_ui")
merge_dict("plugins.locale_zh_cn.dict_settings")

local tr

local function format_default_value(val)
  if val == "true" then return "开启" end
  if val == "false" then return "关闭" end
  return DICT[val] or val
end

local function translate_find_tooltip(text)
  if not (text:find("to select the next match%.")
    or text:find("toggles case sensitivity%.")
    or text:find("toggles regex find%."))
  then
    return nil
  end
  local out = text
  out = out:gsub("%[Regex%]%s*", "[正则] ")
  out = out:gsub("%[Sensitive%]%s*", "[区分大小写] ")
  out = out:gsub("Press (.-) to select the next match%.", "按 %1 选择下一个匹配项。")
  out = out:gsub("%s*(%S+) toggles case sensitivity%.", " %1 切换大小写敏感。")
  out = out:gsub("%s*(%S+) toggles regex find%.", " %1 切换正则查找。")
  return out
end

local PATTERNS = {
  { "^version (.+)$", "版本 %1" },
  { "^Renderer: (.+)$", "渲染器: %1" },
  { "^Result: (%d+) of (%d+)(.*)$", "第 %1 / %2 个匹配%3" },
  { "^Total Replaced: (%d+)$", "共替换 %1 处 (Total)" },
  { "^Find Text In (.+)$", "在 %1 中查找文本" },
  { "^Find Regex In (.+)$", "在 %1 中正则查找" },
  { "^Replace Text (.-) With$", "将文本 %1 替换为" },
  { "^Replace Symbol (.-) With$", "将符号 %1 替换为" },
  { "^Install %((%d+)%)$", "安装 (%1)" },
  { "^Upgrade %((%d+)%)$", "升级 (%1)" },
  { "^Uninstall %((%d+)%)$", "卸载 (%1)" },
  { "^Tag: (.+)$", "标签: %1" },
  {
    "^(%d+) of (%d+) shown | (%d+) selected %((%d+) hidden%)$",
    "显示 %1 / %2 | 已选 %3（另有 %4 个隐藏）"
  },
  {
    "^(%d+) of (%d+) shown | (%d+) selected$",
    "显示 %1 / %2 | 已选 %3"
  },
  {
    "^Replace (.-) with repository version (.-)%? Local changes will be lost%.$",
    "确定要用仓库版本 %2 替换本地插件 %1 吗？本地修改将会丢失。"
  },
  {
    "^(.-)\n\nDependent addons and unused user dependencies may also be removed%. Bundled files will not be removed%.$",
    "%1\n\n关联的扩展插件与未使用的用户依赖项也可能会被一并移除（内置文件不会被删除）。"
  },
  {
    "^The project \"(.-)\" contains a %.pragtical_project%.lua file%.\n\nTrust this project to allow Pragtical to load that file%?$",
    "项目 \"%1\" 包含 .pragtical_project.lua 配置文件。\n\n是否信任此项目并允许 Pragtical 加载该文件？"
  },
  {
    "^\"(.-)\" has unsaved changes%. Quit anyway%?$",
    "\"%1\" 有未保存的更改，确定要退出吗？"
  },
  {
    "^(%d+) docs have unsaved changes%. Quit anyway%?$",
    "有 %1 个文档存在未保存的更改，确定要退出吗？"
  },
  {
    "^Some plugins are not loaded due to version mismatch%. Expected version ([^%.]+)%.%s*(.-)%.%s*Please download a recent version from https://github%.com/pragtical/plugins%.$",
    "部分插件因版本不匹配未能加载（期望版本：%1）。\n\n%2\n\n请从 https://github.com/pragtical/plugins 下载最新版本。"
  },
  {
    "^You are trying to open \"(.-)\"\nDo you want to open this directory here, or in a new window%?$",
    "您正在尝试打开目录 \"%1\"\n您希望在当前窗口打开，还是在新窗口中打开？"
  },
  {
    "^Couldn't save file \"(.-)\"%. Do you want to save to another location%?$",
    "无法保存文件 \"%1\"。是否将其另存为其他位置？"
  },
  { "^(.+) has changed%. Reload this file%?$", "%1 已被外部修改，是否重新加载该文件？" },
  { "^Delete Directory$", "删除目录" },
  { "^Delete File$", "删除文件" },
  {
    "^Are you sure you want to delete the directory%?\nDirectory: (.+)$",
    "确定要删除此目录吗？\n目录：%1"
  },
  {
    "^Are you sure you want to delete the file%?\nFile: (.+)$",
    "确定要删除此文件吗？\n文件：%1"
  },
  {
    "^Remove (.-) for (.-)%? Open tabs will stay open%.$",
    "确定要删除项目 %2 的会话 \"%1\" 吗？已打开的标签页将保持打开。"
  },
  {
    "^Remove all saved sessions and recovery data for (.-)%? Open tabs will stay open%.$",
    "确定要清空项目 %1 的所有已保存会话和恢复数据吗？已打开的标签页将保持打开。"
  },
  { "^Open (https?://.+)$", "打开链接 %1" },
  { "^Open (#.+)$", "跳转到锚点 %1" },
  { "^Flying Island Opacity: (.+)$", "Flying Island 不透明度: %1" },
}

tr = function(text)
  if not M.enabled or type(text) ~= "string" or text == "" then
    return text
  end

  local direct = DICT[text]
  if direct then
    return direct
  end

  if text:sub(-1) == ":" then
    local stem = text:sub(1, -2)
    if DICT[stem] then
      return DICT[stem] .. "："
    end
  end

  local desc, def = text:match("^(.-)%s*%(default:%s*(.-)%)$")
  if desc and def then
    local def_zh = format_default_value(def)
    if desc == "" then
      return "（默认：" .. def_zh .. "）"
    end
    return tr(desc) .. "（默认：" .. def_zh .. "）"
  end

  local find_tip = translate_find_tooltip(text)
  if find_tip then
    return find_tip
  end

  for _, rule in ipairs(PATTERNS) do
    local replaced, count = text:gsub(rule[1], rule[2], 1)
    if count > 0 then
      return replaced
    end
  end

  return text
end

M.tr = tr

if not M.enabled then
  return M
end

local wrapped_providers = setmetatable({}, { __mode = "k" })

local function translate_menu_items(items, visited)
  if type(items) ~= "table" then return end
  visited = visited or {}
  if visited[items] then return end
  visited[items] = true

  for _, item in ipairs(items) do
    if type(item) == "table" and item ~= MenuView.DIVIDER and item ~= ContextMenu.DIVIDER and not item.divider then
      if type(item.text) == "string" then
        item.text = tr(item.text)
      end
      if type(item.items) == "table" then
        translate_menu_items(item.items, visited)
      elseif type(item.items) == "function" and not wrapped_providers[item.items] then
        local orig_fn = item.items
        local wrapped_fn = function(...)
          local result = orig_fn(...)
          if type(result) == "table" then
            translate_menu_items(result)
          end
          return result
        end
        wrapped_providers[wrapped_fn] = true
        item.items = wrapped_fn
      end
    end
  end
end

local function translate_styled_text(tbl)
  if type(tbl) ~= "table" then return tr(tbl) end
  local copy = {}
  for i, v in ipairs(tbl) do
    if type(v) == "string" and not v:match("^%s%s") then
      copy[i] = tr(v)
    else
      copy[i] = v
    end
  end
  return copy
end

-- 1. MenuView Hook
local function wrap_menu_view()
  translate_menu_items(core.menu_view.items)
  core.menu_view.revision = core.menu_view.revision + 1
  core.menu_view.label_layout = nil

  local orig_register = MenuView.register
  function MenuView:register(path, items, name)
    translate_menu_items(items)
    return orig_register(self, path, items, name)
  end

  local orig_measure_labels = MenuView.measure_labels
  function MenuView:measure_labels()
    local layout = orig_measure_labels(self)
    if layout then
      layout.compact_width = style.font:get_width(tr("Menu")) + style.padding.x * 2
    end
    return layout
  end

  local orig_each_label = MenuView.each_label
  function MenuView:each_label()
    local iter = orig_each_label(self)
    local compact_label = tr("Menu")
    return function()
      local i, text, x, width = iter()
      if i == 0 and text == "Menu" then
        text = compact_label
      end
      return i, text, x, width
    end
  end
end

-- 2. ContextMenu Hook
local function wrap_context_menu()
  local orig_register = ContextMenu.register
  function ContextMenu:register(predicate, items)
    translate_menu_items(items)
    return orig_register(self, predicate, items)
  end

  local orig_show_items = ContextMenu.show_items
  function ContextMenu:show_items(source, x, y, options)
    if type(source) == "table" then
      translate_menu_items(source)
    elseif type(source) == "function" and not wrapped_providers[source] then
      local orig_fn = source
      local wrapped_fn = function(...)
        local result = orig_fn(...)
        if type(result) == "table" then
          translate_menu_items(result)
        end
        return result
      end
      wrapped_providers[wrapped_fn] = true
      source = wrapped_fn
    end
    return orig_show_items(self, source, x, y, options)
  end

  -- 针对先于插件加载创建的 EmptyView.recent_projects_menu 进行补译
  if EmptyView.recent_projects_menu and type(EmptyView.recent_projects_menu.itemset) == "table" then
    for _, entry in ipairs(EmptyView.recent_projects_menu.itemset) do
      translate_menu_items(entry.items)
    end
  end
end

-- 3. NagView Hook (保留原始 item 对象给 on_selected，确保逻辑判断不被破坏)
local function wrap_nag_view()
  local orig_show = NagView.show
  function NagView:show(title, message, options, on_selected)
    local translated_opts = {}
    if type(options) == "table" then
      for i, opt in ipairs(options) do
        local copy = {}
        for k, v in pairs(opt) do
          copy[k] = v
        end
        if type(opt.text) == "string" then
          copy.text = tr(opt.text)
        end
        copy._orig_opt = opt
        translated_opts[i] = copy
      end
    end

    local wrapped_cb = on_selected and function(selected)
      return on_selected(selected and selected._orig_opt or selected)
    end or nil

    return orig_show(self, tr(title), tr(message), translated_opts, wrapped_cb)
  end
end

-- 4. CommandView Hook (保持 self.label 英文原值以确保外部比对安全，仅在测量与绘制时临时替换为译文)
local function wrap_command_view()
  local orig_enter = CommandView.enter
  function CommandView:enter(label, ...)
    self._display_label = type(label) == "string" and (tr(label) .. ": ") or nil
    return orig_enter(self, label, ...)
  end

  local orig_exit = CommandView.exit
  function CommandView:exit(...)
    local res = orig_exit(self, ...)
    self._display_label = nil
    return res
  end

  local function with_display_label(self, fn, ...)
    local orig_label = self.label
    local display = self._display_label
    if not display and type(orig_label) == "string" and orig_label:sub(-2) == ": " then
      display = tr(orig_label:sub(1, -3)) .. ": "
    end
    if display and display ~= orig_label then
      self.label = display
      local r1, r2, r3 = fn(self, ...)
      self.label = orig_label
      return r1, r2, r3
    end
    return fn(self, ...)
  end

  local orig_update = CommandView.update
  function CommandView:update(...)
    return with_display_label(self, orig_update, ...)
  end

  local orig_draw_line_gutter = CommandView.draw_line_gutter
  function CommandView:draw_line_gutter(...)
    return with_display_label(self, orig_draw_line_gutter, ...)
  end
end

-- 5. StatusView Hook
local function translate_status_items()
  for _, item in ipairs(core.status_view.items) do
    if type(item.tooltip) == "string" and item.tooltip ~= "" then
      item.tooltip = tr(item.tooltip)
    end
  end
end

local function wrap_status_view()
  translate_status_items()

  local orig_add_item = StatusView.add_item
  function StatusView:add_item(options)
    if type(options) == "table" and type(options.tooltip) == "string" and options.tooltip ~= "" then
      local copy = common.merge({}, options)
      copy.tooltip = tr(options.tooltip)
      return orig_add_item(self, copy)
    end
    return orig_add_item(self, options)
  end

  local orig_show_tooltip = StatusView.show_tooltip
  function StatusView:show_tooltip(text)
    if type(text) == "string" then
      text = tr(text)
    elseif type(text) == "table" then
      text = translate_styled_text(text)
    end
    return orig_show_tooltip(self, text)
  end

  local orig_show_message = StatusView.show_message
  function StatusView:show_message(icon, icon_color, text)
    if type(text) == "string" then
      text = tr(text)
    end
    return orig_show_message(self, icon, icon_color, text)
  end
end

-- 6. Widget Hook
local function wrap_widgets()
  local orig_set_tooltip = Widget.set_tooltip
  function Widget:set_tooltip(tooltip, cmd)
    if type(tooltip) == "string" then
      tooltip = tr(tooltip)
    elseif type(tooltip) == "table" then
      tooltip = translate_styled_text(tooltip)
    end
    return orig_set_tooltip(self, tooltip, cmd)
  end

  local orig_set_label = Widget.set_label
  function Widget:set_label(text)
    if type(text) == "string" then
      text = tr(text)
    end
    return orig_set_label(self, text)
  end

  local orig_label_set_label = Label.set_label
  function Label:set_label(text)
    if type(text) == "string" and not self.wrapping then
      text = tr(text)
    end
    return orig_label_set_label(self, text)
  end

  local orig_widget_get_name = Widget.get_name
  function Widget:get_name()
    local name = orig_widget_get_name(self)
    if type(name) == "string" then
      return DICT[name] or name
    end
    return name
  end

  local orig_toggle_new = Toggle.new
  function Toggle:new(parent, label, enable)
    if type(label) == "string" then
      label = tr(label)
    end
    return orig_toggle_new(self, parent, label, enable)
  end

  local orig_select_set_label = SelectBox.set_label
  function SelectBox:set_label(text)
    if type(text) == "string" then
      text = tr(text)
    end
    return orig_select_set_label(self, text)
  end

  local orig_select_add_option = SelectBox.add_option
  function SelectBox:add_option(text, data)
    if type(text) == "string" then
      text = tr(text)
    end
    return orig_select_add_option(self, text, data)
  end

  local orig_textbox_new = TextBox.new
  function TextBox:new(parent, text, placeholder, options)
    if type(placeholder) == "string" then
      placeholder = tr(placeholder)
    end
    return orig_textbox_new(self, parent, text, placeholder, options)
  end

  local orig_listbox_add_column = ListBox.add_column
  function ListBox:add_column(name, width, expand)
    if type(name) == "string" then
      name = tr(name)
    end
    return orig_listbox_add_column(self, name, width, expand)
  end

  local orig_notebook_add_pane = NoteBook.add_pane
  function NoteBook:add_pane(name, label)
    if type(label) == "string" then
      label = tr(label)
    end
    return orig_notebook_add_pane(self, name, label)
  end

  local orig_foldingbook_add_pane = FoldingBook.add_pane
  function FoldingBook:add_pane(name, label)
    if type(label) == "string" then
      label = tr(label)
    end
    return orig_foldingbook_add_pane(self, name, label)
  end

  local orig_dialog_set_title = Dialog.set_title
  function Dialog:set_title(text)
    if type(text) == "string" then
      text = tr(text)
    end
    return orig_dialog_set_title(self, text)
  end

  local orig_msgbox_set_title = MessageBox.set_title
  function MessageBox:set_title(text)
    if type(text) == "string" then
      text = tr(text)
    end
    return orig_msgbox_set_title(self, text)
  end

  local orig_msgbox_set_message = MessageBox.set_message
  function MessageBox:set_message(text)
    if type(text) == "string" then
      text = tr(text)
    elseif type(text) == "table" then
      text = translate_styled_text(text)
    end
    return orig_msgbox_set_message(self, text)
  end

  local orig_filepicker_set_mode = FilePicker.set_mode
  function FilePicker:set_mode(mode)
    local res = orig_filepicker_set_mode(self, mode)
    if self.textbox and type(self.textbox.placeholder) == "string" then
      self.textbox.placeholder = tr(self.textbox.placeholder)
    end
    return res
  end

  -- 保留 unused 参数避免 strict 报警并覆盖部分直接传字符串给 InputDialog / ColorPickerDialog 的情形
  local orig_input_new = InputDialog.new
  function InputDialog:new(title, message, text)
    return orig_input_new(
      self,
      type(title) == "string" and tr(title) or title,
      type(message) == "string" and tr(message) or message,
      text
    )
  end

  local orig_color_new = ColorPickerDialog.new
  function ColorPickerDialog:new(title, color)
    return orig_color_new(
      self,
      type(title) == "string" and tr(title) or title,
      color
    )
  end

  local _ = { Button, CheckBox, ToggleButton }
end

-- 7. View 标题与先创建的 EmptyView 补译
local function translate_empty_view(view)
  if type(view.name) == "string" then
    view.name = tr(view.name)
  end
  for _, container in ipairs { view.top_container, view.center_container } do
    if container and type(container.childs) == "table" then
      for _, btn in ipairs(container.childs) do
        if type(btn.label) == "string" then
          btn:set_label(tr(btn.label))
        end
        if type(btn.tooltip) == "string" then
          btn:set_tooltip(tr(btn.tooltip), btn.tooltip_command)
        end
      end
    end
  end
  if view.recent_projects and type(view.recent_projects.columns) == "table" then
    for _, col in ipairs(view.recent_projects.columns) do
      if type(col.name) == "string" then
        col.name = tr(col.name)
        col.width = view.recent_projects:get_font():get_width(col.name)
      end
    end
  end
  if view.prev_size then
    view.prev_size.x = -1
  end
end

local wrapped_view_classes = setmetatable({}, { __mode = "k" })

local function wrap_view_get_name(cls)
  if not cls or wrapped_view_classes[cls] then return end
  if type(cls.get_name) == "function" then
    local orig_get_name = cls.get_name
    cls.get_name = function(self, ...)
      local name = orig_get_name(self, ...)
      if type(name) == "string" then
        return tr(name)
      end
      return name
    end
  end
  wrapped_view_classes[cls] = true
end

local function wrap_views()
  wrap_view_get_name(LogView)

  local orig_empty_new = EmptyView.new
  function EmptyView:new(...)
    local res = orig_empty_new(self, ...)
    self.name = tr(self.name)
    return res
  end

  -- 补译 core.init() 阶段早于插件创建的 EmptyView
  if core.root_view and core.root_view.root_node then
    for _, view in ipairs(core.root_view.root_node:get_children()) do
      if view:is(EmptyView) then
        translate_empty_view(view)
      end
    end
  end

  local orig_add_view = Node.add_view
  function Node:add_view(view, ...)
    if view
      and not (view:extends(DocView)
        or view:extends(ImageView)
        or view:extends(MarkdownView)
        or view:extends(AudioView))
    then
      local mt = getmetatable(view)
      if mt then
        wrap_view_get_name(mt)
      end
    end
    return orig_add_view(self, view, ...)
  end
end

wrap_menu_view()
wrap_context_menu()
wrap_nag_view()
wrap_command_view()
wrap_status_view()
wrap_widgets()
wrap_views()

-- 所有插件加载完成后再补扫一次菜单与状态栏，并包裹延迟加载的视图类
core.add_thread(function()
  translate_menu_items(core.menu_view.items)
  core.menu_view.revision = core.menu_view.revision + 1
  core.menu_view.label_layout = nil

  translate_status_items()

  local plugin_view = package.loaded["plugins.plugin_manager.plugin_view"]
  if type(plugin_view) == "table" then
    wrap_view_get_name(plugin_view)
  end

  core.redraw = true
end)

return M

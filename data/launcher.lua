--------------------------------------------------------------------------------
--- THlib 启动器
--- code by 璀境石
--------------------------------------------------------------------------------
do return end
--------------------------------------------------------------------------------

local i18n = require("lib.i18n")

local i18n_str = i18n.string

--------------------------------------------------------------------------------

---@type ui
local subui = lstg.DoFile("lib/ui.lua")

---@class launcher.menu.Base : lstg.GameObject

---@param obj launcher.menu.Base
local function initMenuObjectCommon(obj)
    obj.layer = LAYER_TOP
    obj.group = GROUP_GHOST
    obj.bound = false -- 飞入飞出可能会离开版面

    -- 菜单飞入飞出
    obj.alpha = 1.0
    obj.alpha0 = 0.0
    obj.x = screen.width * 0.5 - screen.width
    obj.y = screen.height * 0.5
    obj.locked = true
end

--------------------------------------------------------------------------------

---@return string[]
local function enumMods()
    local list = {}
    local pos = 1
    local list_mods = lstg.FileManager.EnumFiles('mod/')
    for _, v in ipairs(list_mods) do
        local filename = v[1]
        local mod_name = ""
        if string.sub(filename, -4, -1) == ".zip" then
            -- 压缩包 mod
            lstg.LoadPack(filename)
            local root_exist = lstg.FileManager.GetArchive(filename):FileExist("root.lua")
            lstg.UnloadPack(filename)
            if root_exist then
                mod_name = string.sub(filename, 5, -5)
            end
        elseif v[2] then
            -- 文件夹 mod
            if lstg.FileManager.FileExist(v[1] .. "root.lua") then
                mod_name = string.sub(filename, 5, -2)
            end
        end
        if string.len(mod_name) > 0 then
            if mod_name ~= 'launcher' then
                table.insert(list, mod_name)
            end
            if setting.last_mod == mod_name then
                pos = #list
            end
        end
    end
    return list, pos
end

--- 前置声明，实际实现在下方的 launcher_scene
---@param mod_name string
local function setMod(mod_name) end

---@class launcher.menu.SelectMod : launcher.menu.Base
local SelectMod = Class(object)

---@param exit_f fun()
function SelectMod:init(exit_f)
    initMenuObjectCommon(self)

    self.title = ""
    self.exit_func = exit_f

    local _w_height = 16 + 4 * 2 -- 上下都留空隙
    local _width = screen.width - 16 * 2 -- 两侧留边缘
    local _height = 18 * _w_height

    self._back = subui.widget.Button("", exit_f)
    self._back.width = _width / 4
    self._back.height = _w_height

    self._view = subui.layout.LinearScrollView(_width, _height)
    self._view.scroll_height = _w_height -- 一次滚轮滚动一个按键

    function self:_updateViewState()
        self._view.alpha = self.alpha
        self._view.x = self.x - _width / 2
        self._view.y = self.y + _height / 2 - _w_height -- 降一个控件高度

        self._back.alpha = self.alpha
        self._back.x = self.x - _width / 2
        self._back.y = self.y + _height / 2 + _w_height
    end
    function self:refresh()
        self.title = i18n_str("launcher.menu.start.select")
        self._back.text = i18n_str("launcher.back_icon")
        local mods_, pos_ = enumMods()
        local ws_ = {}
        for i, v in ipairs(mods_) do
            local idx = i
            local mod = v
            local w_button = subui.widget.Button(string.format("%d. %s", idx, mod), function()
                subui.sound.playConfirm()
                setMod(mod)
            end)
            w_button.width = _width
            w_button.height = _w_height
            table.insert(ws_, w_button)
        end
        self._view:setWidgets(ws_)
        self._view._index = pos_
    end

    self:_updateViewState() -- 先更新一次
    self:refresh()
end

function SelectMod:frame()
    task.Do(self)
    self:_updateViewState()
    if not self.locked then
        if self.exit_func and (subui.keyboard.cancel.down or subui.mouse.xbutton1.down) then
            self.exit_func()
        end
    end
    self._back:update(not self.locked and subui.isMouseInRect(self._back))
    self._view:update(not self.locked)
end

function SelectMod:render()
    if self.alpha0 >= 0.0001 then
        SetViewMode("ui")
        local y = self.y + 9.5 * 24
        subui.drawTTF("ttf:menu-font", self.title, self.x, self.x, y, y, lstg.Color(self.alpha * 255, 255, 255, 255), "center", "vcenter")
        self._back:draw()
        self._view:draw()
        SetViewMode("world")
    end
end

---@param exit_f fun()
---@return launcher.menu.SelectMod
function SelectMod.create(exit_f)
    return lstg.New(SelectMod, exit_f)
end

--------------------------------------------------------------------------------

---@class launcher.menu.TextInput : launcher.menu.Base
local TextInput = Class(object)

function TextInput:init()
    initMenuObjectCommon(self)

    self.title = ""
    ---@type fun(text:string)
    self.callback = function() end
    self.text_max_length = 8
    self.text = ""

    local _w_height = 16 + 4 * 2 -- 上下都留空隙
    local _width = _w_height * 13 -- 屏幕键盘宽度
    local _height = 18 * _w_height

    self._back = subui.widget.Button("", function()
        self.callback(false)
    end)
    self._back.width = _width / 4
    self._back.height = _w_height

    local __0 = "\0"
    local __3 = "\3"
    local __8 = "\8"
    local _bs = "\\"
    local _sp = " "
    local chars = {
        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
        "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
        "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
        "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ",", ".", "_",
        "+", "-", "*", "/", "=", "<", ">", "(", ")", "[", "]", "{", "}",
        "#", "$", "%", "&", "@", ":", ";", "!", "?", "^", "~", "`", "|",
        _bs, '"', "'", __0, __0, __0, __0, __0, __0, __0, _sp, __8, __3,
    }
    ---@type ui.widget.Button[]
    local buttons = {}
    for _, v in ipairs(chars) do
        local ch = v
        local w_button = subui.widget.Button(ch, function()
            if self.text:len() < self.text_max_length then
                self.text = self.text .. ch
            end
        end)
        if ch == _sp then
            w_button.text = "␣"
        elseif ch == __8 then
            w_button.text = "←"
            w_button.callback = function()
                if self.text:len() > 0 then
                    self.text = self.text:sub(1, self.text:len() - 1)
                end
            end
        elseif ch == __3 then
            w_button.text = "✓"
            w_button.callback = function()
                self.callback(self.text)
            end
        elseif ch == __0 then
            w_button.text = ""
            w_button.callback = function() end
        end
        w_button.width = 24
        w_button.height = 24
        w_button.halign = "center"
        table.insert(buttons, w_button)
    end
    table.insert(buttons, self._back)
    self._button = buttons
    self._button_index = 1

    function self:_updateButtonLayout()
        local lw = 24 * 13
        local lh = 24 * 8
        local lx = self.x - lw / 2
        local ly = self.y + lh / 2
        for j = 0, 7 do
            for i = 0, 12 do
                local w = buttons[j * 13 + i + 1]
                w.alpha = self.alpha
                w.x = lx + i * 24
                w.y = ly - j * 24
            end
        end

        self._back.alpha = self.alpha
        self._back.x = self.x - _width / 2
        self._back.y = self.y + _height / 2 + _w_height
    end

    ---@param title string
    ---@param init_text string
    ---@param cb fun(text:string)
    function self:reset(title, init_text, cb)
        self._button_index = 1
        self.title = i18n_str(title)
        self._back.text = i18n_str("launcher.back_icon")
        if init_text then
            self.text = init_text
        end
        self.callback = cb
    end

    self:_updateButtonLayout()
end

function TextInput:frame()
    local function indexToPos()
        local zero_base = self._button_index - 1
        return (zero_base % 13) + 1,
            math.floor(zero_base / 13) + 1
    end
    local function posToIndex(x, y)
        x = math.max(1, math.min(x, 13))
        y = math.max(1, math.min(y, 8))
        self._button_index = (y - 1) * 13 + (x - 1) + 1
    end
    task.Do(self)
    self:_updateButtonLayout()
    if not self.locked then
        if subui.keyboard.up.down then
            local x, y = indexToPos()
            y = y - 1
            posToIndex(x, y)
        elseif subui.keyboard.down.down then
            local x, y = indexToPos()
            y = y + 1
            posToIndex(x, y)
        elseif subui.keyboard.left.down then
            local x, y = indexToPos()
            x = x - 1
            posToIndex(x, y)
        elseif subui.keyboard.right.down then
            local x, y = indexToPos()
            x = x + 1
            posToIndex(x, y)
        elseif subui.keyboard.cancel.down then
            if self.text:len() > 0 then
                self.text = self.text:sub(1, self.text:len() - 1)
            else
                self.callback(nil)
            end
        end
        if subui.mouse.is_move then
            for i, w in ipairs(self._button) do
                if subui.isMouseInRect(w) then
                    self._button_index = i
                end
            end
        end
    end
    for i, w in ipairs(self._button) do
        w:update(not self.locked and i == self._button_index)
    end
end

function TextInput:render()
    if self.alpha0 > 0.0001 then
        SetViewMode("ui")
        local y = self.y + 9.5 * 24
        subui.drawTTF("ttf:menu-font", self.title, self.x, self.x, y, y, lstg.Color(self.alpha * 255, 255, 255, 255), "center", "vcenter")
        y = y - 24 * 3
        local w2 = 13 * 24 * 0.5
        lstg.SetImageState("img:menu-white", "", lstg.Color(self.alpha * 32, 255, 255, 255))
        lstg.RenderRect("img:menu-white",
            self.x - w2, self.x + w2,
            y - 12, y + 12)
        subui.drawTTF("ttf:menu-font", self.text, self.x, self.x, y, y, lstg.Color(self.alpha * 255, 255, 255, 255), "center", "vcenter")
        for _, w in ipairs(self._button) do
            w:draw()
        end
        SetViewMode("world")
    end
end

---@return launcher.menu.TextInput
function TextInput.create()
    return lstg.New(TextInput)
end

--------------------------------------------------------------------------------

---@class launcher.menu.MainMenu : launcher.menu.Base
local Main = Class(object)

---@param exit_f fun()
function Main:init(exit_f, entries)
    initMenuObjectCommon(self)

    self.exit_func = exit_f

    local _w_height = 16 + 4 * 2 -- 上下都留空隙
    local _width = 200 --screen.width - 16 * 2 -- 两侧留边缘
    local _height = 7 * _w_height

    self._view = subui.layout.LinearScrollView(_width, _height)
    self._view.scroll_height = _w_height -- 一次滚轮滚动一个按键

    function self:_updateViewState()
        self._view.alpha = self.alpha
        self._view.x = self.x - _width / 2
        self._view.y = self.y + _height / 2
    end
    function self:refresh()
        local _updateTextFunc = {}
        local function _updateText()
            for _, f in ipairs(_updateTextFunc) do
                f()
            end
        end

        local ws_ = {}
        for _, v in ipairs(entries) do
            if v[1] == "$lang" then
                local lci = 1
                local lcs = i18n.listLocale()
                local lcname = {}
                for i, v in ipairs(lcs) do
                    lcname[i] = v.name
                    if setting and setting.locale and setting.locale == v.id then
                        lci = i
                    end
                end
                local w_simpleselector_lang = subui.widget.SimpleSelector()
                    :setText("")
                    :setRect(0, 0, _width, _w_height)
                    :setCallback(function (value)
                        -- NO OP
                    end, function()
                        return lci
                    end, function(value)
                        lci = value
                        i18n.setLocale(lcs[lci].id)
                        _updateText()
                        setting.locale = lcs[lci].id
                        saveConfigure()
                    end)
                w_simpleselector_lang._split_factor = 0.0
                w_simpleselector_lang._item = lcname
                table.insert(ws_, w_simpleselector_lang)
            else
                local val = v
                local w_button = subui.widget.Button(i18n_str(val[1]), function()
                    val[2]()
                end)
                w_button.width = _width
                w_button.height = _w_height
                w_button.halign = "center"
                table.insert(ws_, w_button)
                table.insert(_updateTextFunc, function()
                    w_button.text = i18n_str(val[1])
                end)
            end
        end

        self._view:setWidgets(ws_)
    end

    self:_updateViewState() -- 先更新一次
    self:refresh()
end

function Main:frame()
    task.Do(self)
    if not self.locked and self.exit_func and (subui.keyboard.cancel.down or subui.mouse.xbutton1.down) then
        self.exit_func()
    end
    self:_updateViewState()
    self._view:update(not self.locked)
end

function Main:render()
    if self.alpha0 >= 0.0001 then
        SetViewMode("ui")
        self._view:draw()
        SetViewMode("world")
    end
end

---@param exit_f fun()
---@return launcher.menu.MainMenu
function Main.create(exit_f, entries)
    return lstg.New(Main, exit_f, entries)
end

--------------------------------------------------------------------------------

---@class launcher.menu.InputSetting : launcher.menu.Base
local InputSetting = Class(object)

---@param exit_f fun()
function InputSetting:init(exit_f)
    initMenuObjectCommon(self)

    self.title = "?"
    self.exit_func = exit_f

    local _w_height = 16 + 4 * 2 -- 上下都留空隙
    local _width = screen.width - 16 * 2 -- 两侧留边缘
    local _height = 18 * _w_height

    -- 以前的设置

    local last_setting_copy = {}
    local last_setting = {}
    local function copyDataFromSetting()
        for k, v in pairs(setting.keys) do
            last_setting[k] = v
            last_setting_copy[k] = v
        end
        for k, v in pairs(setting.keysys) do
            last_setting[k] = v
            last_setting_copy[k] = v
        end
    end
    local function copyDataToSetting()
        for k, _ in pairs(setting.keys) do
            setting.keys[k] = last_setting[k]
        end
        for k, _ in pairs(setting.keysys) do
            setting.keysys[k] = last_setting[k]
        end
    end
    local function copyDataFromDefaultSetting()
        for k, v in pairs(default_setting.keys) do
            last_setting[k] = v
            last_setting_copy[k] = v
        end
        for k, v in pairs(default_setting.keysys) do
            last_setting[k] = v
            last_setting_copy[k] = v
        end
    end

    local keys = {
        { "launcher.action.left", "keys", "left" },
        { "launcher.action.right", "keys", "right" },
        { "launcher.action.up", "keys", "up" },
        { "launcher.action.down", "keys", "down" },
        { "launcher.action.slow", "keys", "slow" },
        { "launcher.action.shoot", "keys", "shoot" },
        { "launcher.action.spell", "keys", "spell" },
        { "launcher.action.special", "keys", "special" },
        { "launcher.action.menu", "keysys", "menu" },
        { "launcher.action.snapshot", "keysys", "snapshot" },
        { "launcher.action.repfast", "keysys", "repfast" },
        { "launcher.action.repslow", "keysys", "repslow" },
    }

    ---@type ui.widget.Text[]
    local texts = {}
    ---@type ui.widget.Button[]
    local keysetup = {}
    ---@type ui.widget.Button[]
    local buttons = {}

    self._back = subui.widget.Button("?", function()
        self:_discard()
        self.exit_func()
    end)
    self._back.width = _width / 4
    self._back.height = _w_height

    local key_code_to_name = KeyCodeToName()
    for i, v in ipairs(keys) do
        local idx = i
        local cfg = v

        local w_button = subui.widget.Button("", function() end)
        function w_button.updateText()
            local vkey = last_setting[cfg[3]]
            w_button.text = key_code_to_name[vkey]
        end
        w_button.callback = function()
            self.locked = true
            self._current_edit = idx
            task.New(self, function()
                local last_key = KEY.NULL
                for i = 1, 240 do
                    task.Wait(1)
                    last_key = lstg.GetLastKey()
                    if last_key ~= KEY.NULL then
                        break
                    end
                end
                if last_key ~= KEY.NULL then
                    last_setting[cfg[3]] = last_key
                    w_button.updateText()
                end
                task.Wait(1)
                self.locked = false
                self._current_edit = 0
            end)
        end
        w_button.width = _width
        w_button.height = _w_height
        w_button.halign = "right"
        table.insert(buttons, w_button)
        table.insert(keysetup, w_button)

        local w_text = subui.widget.Text(i18n_str(cfg[1]))
        w_text.width = _width
        w_text.height = _w_height
        table.insert(texts, w_text)
    end
    local function updateButtonText()
        for _, w in ipairs(keysetup) do
            w.updateText()
        end
    end

    self._current_edit = 0
    self._text = texts
    self._button = buttons
    self._button_index = 1

    self._restore = subui.widget.Button("?", function()
        copyDataFromDefaultSetting()
        updateButtonText()
    end)
    self._restore.width = _width
    self._restore.height = _w_height

    self._save = subui.widget.Button("?", function()
        copyDataToSetting()
        saveConfigure()
        self.exit_func()
    end)
    self._save.width = _width
    self._save.height = _w_height

    table.insert(buttons, self._restore)
    table.insert(buttons, self._save)
    self._save_index = #buttons
    table.insert(buttons, self._back)

    function self:_updateButtonLayout()
        local top_y = self.y + 8 * _w_height
        for i, w in ipairs(buttons) do
            w.alpha = self.alpha
            if w == self._back then
                w.x = self.x - _width / 2
                w.y = self.y + _height / 2 + _w_height
            else
                w.x = self.x - _width / 2
                w.y = top_y - (i - 1) * _w_height
            end
        end
        for i, w in ipairs(texts) do
            w.alpha = self.alpha
            w.x = self.x - _width / 2
            w.y = top_y - (i - 1) * _w_height
        end
    end

    function self:refresh()
        self.title = i18n_str("launcher.menu.setting.input.keyboard")
        self._back.text = i18n_str("launcher.back_icon")
        self._restore.text = i18n_str("launcher.restore_to_default")
        self._save.text = i18n_str("launcher.save_and_return")
        self._button_index = 1
        copyDataFromSetting()
        updateButtonText() -- 因为设置可能有变化
    end

    function self:_discard()
        -- NO OP
    end

    self:refresh()
    self:_updateButtonLayout()
end

function InputSetting:frame()
    local function formatIndex()
        self._button_index = ((self._button_index - 1) % #self._button) + 1
    end
    task.Do(self)
    self:_updateButtonLayout()
    if not self.locked then
        if subui.keyboard.up.down then
            self._button_index = self._button_index - 1
            formatIndex()
        elseif subui.keyboard.down.down then
            self._button_index = self._button_index + 1
            formatIndex()
        elseif subui.keyboard.cancel.down then
            if self._button_index ~= #self._button then
                self._button_index = #self._button
            else
                self:_discard()
                self.exit_func()
            end
        end
        if subui.mouse.is_move then
            for i, w in ipairs(self._button) do
                if subui.isMouseInRect(w) then
                    self._button_index = i
                end
            end
        end
    end
    for i, w in ipairs(self._button) do
        w:update(not self.locked and i == self._button_index)
    end
    for i, w in ipairs(self._text) do
        w:update(not self.locked and i == self._button_index)
    end
end

function InputSetting:render()
    if self.alpha0 > 0.0001 then
        SetViewMode("ui")
        local y = self.y + 9.5 * 24
        subui.drawTTF("ttf:menu-font", self.title, self.x, self.x, y, y, lstg.Color(self.alpha * 255, 255, 255, 255), "center", "vcenter")
        for i, w in ipairs(self._button) do
            if i == self._current_edit then
                local a = 48 + 16 * math.sin(self.timer / math.pi)
                lstg.SetImageState("img:menu-white", "", lstg.Color(self.alpha * a, 255, 255, 255))
                lstg.RenderRect("img:menu-white", w.x, w.x + w.width, w.y - w.height, w.y)
            end
            w:draw()
        end
        for _, w in ipairs(self._text) do
            w:draw()
        end
        SetViewMode("world")
    end
end

---@param exit_f fun()
---@return launcher.menu.InputSetting
function InputSetting.create(exit_f)
    return lstg.New(InputSetting, exit_f)
end

--------------------------------------------------------------------------------

---@class launcher.menu.GameSetting : launcher.menu.Base
local GameSetting = Class(object)

---@param exit_f fun()
function GameSetting:init(exit_f)
    initMenuObjectCommon(self)

    self.title = "?"
    self.exit_func = exit_f

    local _w_height = 16 + 4 * 2 -- 上下都留空隙
    local _width = screen.width - 16 * 2 -- 两侧留边缘
    local _height = 18 * _w_height

    ---@type ui.widget.Button[]
    self._button = {}
    self._button_index = 2

    -- 直接返回

    local w_button_back = subui.widget.Button("?", function()
        self:_discard()
        self.exit_func()
    end)
    w_button_back.width = _width / 4
    w_button_back.height = _w_height
    table.insert(self._button, w_button_back)

    -- 旧设置

    local last_setting_copy = {
        resx = setting.resx,
        resy = setting.resy,
        windowed = setting.windowed,
        vsync = setting.vsync,
        sevolume = setting.sevolume,
        bgmvolume = setting.bgmvolume,
    }
    local last_setting = {
        resx = setting.resx,
        resy = setting.resy,
        windowed = setting.windowed,
        vsync = setting.vsync,
        sevolume = setting.sevolume,
        bgmvolume = setting.bgmvolume,
    }
    local function copyDataFromSetting()
        last_setting_copy.resx = setting.resx
        last_setting_copy.resy = setting.resy
        last_setting_copy.windowed = setting.windowed
        last_setting_copy.vsync = setting.vsync
        last_setting_copy.sevolume = setting.sevolume
        last_setting_copy.bgmvolume = setting.bgmvolume

        last_setting.resx = setting.resx
        last_setting.resy = setting.resy
        last_setting.windowed = setting.windowed
        last_setting.vsync = setting.vsync
        last_setting.sevolume = setting.sevolume
        last_setting.bgmvolume = setting.bgmvolume
    end
    local function copyDataToSetting()
        setting.resx = last_setting.resx
        setting.resy = last_setting.resy
        setting.windowed = last_setting.windowed
        setting.vsync = last_setting.vsync
        setting.sevolume = last_setting.sevolume
        setting.bgmvolume = last_setting.bgmvolume
    end

    -- 显示设置

    local mode_window = {
        { 640, 480, 60, 1 },
        { 800, 600, 60, 1 },
        { 960, 720, 60, 1 },
        { 1024, 768, 60, 1 },
        { 1280, 960, 60, 1 },
        { 1600, 1200, 60, 1 },
        { 1920, 1440, 60, 1 },
    }
    local mode_window_index = 1
    local mode_window_name = {}
    local mode_fullscreen = {
        { 640, 480, 60, 1 },
    }
    local mode_fullscreen_index = 1
    local mode_fullscreen_name = {}
    local function updateDisplayMode()
        mode_fullscreen = lstg.EnumResolutions()
        local cfg = last_setting

        mode_window_index = 0
        for i, v in ipairs(mode_window) do
            if v[1] == cfg.resx and v[2] == cfg.resy then
                mode_window_index = i
                break
            end
        end
        if mode_window_index == 0 then
            for i, v in ipairs(mode_window) do
                if v[1] == cfg.resx or v[2] == cfg.resy then
                    mode_window_index = i
                    break
                end
            end
        end
        if mode_window_index == 0 then
            mode_window_index = 1 -- fallback
        end

        mode_fullscreen_index = 0
        for i, v in ipairs(mode_fullscreen) do
            if v[1] == cfg.resx and v[2] == cfg.resy and (v[3] / v[4]) > 58.5 then
                mode_fullscreen_index = i
                break
            end
        end
        if mode_fullscreen_index == 0 then
            for i, v in ipairs(mode_fullscreen) do
                if (v[1] == cfg.resx or v[2] == cfg.resy) and (v[3] / v[4]) > 58.5 then
                    mode_fullscreen_index = i
                    break
                end
            end
        end
        if mode_fullscreen_index == 0 then
            mode_fullscreen_index = 1 -- fallback
        end

        mode_window_name = {}
        for i, v in ipairs(mode_window) do
            mode_window_name[i] = string.format("%dx%d@%s", v[1], v[2], i18n_str("launcher.menu.setting.game.desktop_refresh_rate"))
        end

        mode_fullscreen_name = {}
        for i, v in ipairs(mode_fullscreen) do
            mode_fullscreen_name[i] = string.format("%dx%d@%.2fHz", v[1], v[2], v[3] / v[4])
        end
    end

    local w_simpleselector_mode = subui.widget.SimpleSelector()
        :setText("?")
        :setRect(0, 0, _width, _w_height)
        :setCallback(function (value)
            -- NO OP
        end, function ()
            if last_setting.windowed then
                return mode_window_index
            else
                return mode_fullscreen_index
            end
        end, function (value)
            if last_setting.windowed then
                mode_window_index = value
            else
                mode_fullscreen_index = value
            end
        end)
    local function updateModeText()
        if last_setting.windowed then
            w_simpleselector_mode._item = mode_window_name
        else
            w_simpleselector_mode._item = mode_fullscreen_name
        end
    end
    table.insert(self._button, w_simpleselector_mode)

    local w_checkbox_fullscreen = subui.widget.CheckBox()
        :setText("launcher.menu.setting.game.fullscreen")
        :setRect(0, 0, _width, _w_height)
        :setCallback(function (value)
            updateModeText()
        end, function ()
            return not last_setting.windowed
        end, function (value)
            last_setting.windowed = not value
        end)
    table.insert(self._button, w_checkbox_fullscreen)

    local w_checkbox_vsync = subui.widget.CheckBox()
        :setText("launcher.menu.setting.game.vsync")
        :setRect(0, 0, _width, _w_height)
        :setCallback(function (value)
            -- NO OP
        end, function ()
            return last_setting.vsync
        end, function (value)
            last_setting.vsync = value
        end)
    table.insert(self._button, w_checkbox_vsync)

    -- 音量设置

    local w_slider_se = subui.widget.Slider()
        :setText("launcher.menu.setting.game.sound_effect")
        :setRect(0, 0, _width, _w_height)
        :setValue(0, 0, 100, "%d")
        :setValueStep(1, 1, 10)
        :setCallback(function(value)
            lstg.SetSEVolume(value / 100.0)
            subui.sound.playSelect()
        end, function ()
            return last_setting.sevolume
        end, function (value)
            last_setting.sevolume = value
        end)
    table.insert(self._button, w_slider_se)

    local w_slider_bgm = subui.widget.Slider()
        :setText("launcher.menu.setting.game.music")
        :setRect(0, 0, _width, _w_height)
        :setValue(0, 0, 100, "%d")
        :setValueStep(1, 1, 10)
        :setCallback(function(value)
            lstg.SetBGMVolume(value / 100.0)
        end, function ()
            return last_setting.bgmvolume
        end, function (value)
            last_setting.bgmvolume = value
        end)
    table.insert(self._button, w_slider_bgm)

    -- 应用

    local function applySetting()
        if not lstg.ChangeVideoMode(setting.resx, setting.resy, setting.windowed, setting.vsync) then
            setting.windowed = true
            saveConfigure()
            if not lstg.ChangeVideoMode(setting.resx, setting.resy, setting.windowed, setting.vsync) then
                stage.QuitGame()
                return
            end
        end
        ResetScreen()
        lstg.SetSEVolume(setting.sevolume / 100)
        lstg.SetBGMVolume(setting.bgmvolume / 100)
    end
    local w_button_apply = subui.widget.Button("launcher.save_and_return", function()
        if last_setting.windowed then
            last_setting.resx = mode_window[mode_window_index][1]
            last_setting.resy = mode_window[mode_window_index][2]
        else
            last_setting.resx = mode_fullscreen[mode_fullscreen_index][1]
            last_setting.resy = mode_fullscreen[mode_fullscreen_index][2]
        end
        copyDataToSetting()
        saveConfigure()
        applySetting()
        self.exit_func()
    end)
    w_button_apply.width = _width
    w_button_apply.height = _w_height
    table.insert(self._button, w_button_apply)

    -- 刷新

    function self:refresh()
        self.title = i18n_str("launcher.menu.setting.game")
        w_button_back.text = i18n_str("launcher.back_icon")
        w_simpleselector_mode.text = i18n_str("launcher.menu.setting.game.display_mode")
        w_checkbox_fullscreen.text = i18n_str("launcher.menu.setting.game.fullscreen")
        w_checkbox_vsync.text = i18n_str("launcher.menu.setting.game.vsync")
        w_slider_se.text = i18n_str("launcher.menu.setting.game.sound_effect")
        w_slider_bgm.text = i18n_str("launcher.menu.setting.game.music")
        w_button_apply.text = i18n_str("launcher.save_and_return")
        copyDataFromSetting()
        updateDisplayMode()
        updateModeText()
        self._button_index = 2
    end
    function self:_discard()
        lstg.SetSEVolume(last_setting_copy.sevolume / 100)
        lstg.SetBGMVolume(last_setting_copy.bgmvolume / 100)
    end

    -- 地狱布局

    function self:_updateLayout()
        w_button_back.alpha = self.alpha
        w_button_back.x = self.x - _width / 2
        w_button_back.y = self.y + _height / 2 + _w_height

        local top_y = self.y + 8 * _w_height

        w_simpleselector_mode.alpha = self.alpha
        w_simpleselector_mode.x = self.x - _width / 2
        w_simpleselector_mode.y = top_y

        top_y = top_y - _w_height

        w_checkbox_fullscreen.alpha = self.alpha
        w_checkbox_fullscreen.x = self.x - _width / 2
        w_checkbox_fullscreen.y = top_y

        top_y = top_y - _w_height

        w_checkbox_vsync.alpha = self.alpha
        w_checkbox_vsync.x = self.x - _width / 2
        w_checkbox_vsync.y = top_y

        top_y = top_y - _w_height

        w_slider_se.alpha = self.alpha
        w_slider_se.x = self.x - _width / 2
        w_slider_se.y = top_y

        top_y = top_y - _w_height

        w_slider_bgm.alpha = self.alpha
        w_slider_bgm.x = self.x - _width / 2
        w_slider_bgm.y = top_y

        top_y = top_y - _w_height

        w_button_apply.alpha = self.alpha
        w_button_apply.x = self.x - _width / 2
        w_button_apply.y = top_y
    end

    self:refresh()
end

function GameSetting:frame()
    local function formatIndex()
        self._button_index = ((self._button_index - 1) % #self._button) + 1
    end
    task.Do(self)
    self:_updateLayout()
    if not self.locked then
        if subui.keyboard.up.down then
            self._button_index = self._button_index - 1
            formatIndex()
        elseif subui.keyboard.down.down then
            self._button_index = self._button_index + 1
            formatIndex()
        elseif subui.keyboard.cancel.down then
            if self._button_index ~= 1 then
                self._button_index = 1
            else
                self:_discard()
                self.exit_func()
            end
        end
        if subui.mouse.is_move then
            for i, w in ipairs(self._button) do
                if subui.isMouseInRect(w) then
                    self._button_index = i
                end
            end
        end
    end
    for i, w in ipairs(self._button) do
        w:update(not self.locked and i == self._button_index)
    end
end

function GameSetting:render()
    if self.alpha0 > 0.0001 then
        SetViewMode("ui")
        local y = self.y + 9.5 * 24
        subui.drawTTF("ttf:menu-font", self.title, self.x, self.x, y, y, lstg.Color(self.alpha * 255, 255, 255, 255), "center", "vcenter")
        for _, w in ipairs(self._button) do
            w:draw()
        end
        SetViewMode("world")
    end
end

---@param exit_f fun()
---@return launcher.menu.GameSetting
function GameSetting.create(exit_f)
    return lstg.New(GameSetting, exit_f)
end

--------------------------------------------------------------------------------

---@class launcher.menu.PluginManager : launcher.menu.Base
local PluginManager = Class(object)

---@param exit_f fun()
function PluginManager:init(exit_f)
    initMenuObjectCommon(self)

    self.title = "launcher.menu.plugin_manager"
    self.exit_func = exit_f

    local _w_height = 16 + 4 * 2 -- 上下都留空隙
    local _width = screen.width - 16 * 2 -- 两侧留边缘
    local _height = 18 * _w_height

    self._back = subui.widget.Button("launcher.back_icon", exit_f)
    self._back.width = _width / 4
    self._back.height = _w_height

    self._view = subui.layout.LinearScrollView(_width, _height)
    self._view.scroll_height = _w_height -- 一次滚轮滚动一个按键

    function self:_updateLayout()
        self._view.alpha = self.alpha
        self._view.x = self.x - _width / 2
        self._view.y = self.y + _height / 2 - _w_height -- 降一个控件高度

        self._back.alpha = self.alpha
        self._back.x = self.x - _width / 2
        self._back.y = self.y + _height / 2 + _w_height
    end

    ---@type lstg.plugin.Config.Entry[]
    self.plugins = {}

    function self:refresh()
        self.title = i18n_str("launcher.menu.plugin_manager")
        self._back.text = i18n_str("launcher.back_icon")

        self.plugins = lstg.plugin.LoadConfig()
        self.plugins = lstg.plugin.FreshConfig(self.plugins)
        lstg.plugin.SaveConfig(self.plugins)

        local ws_ = {}
        for i, v in ipairs(self.plugins) do
            local idx = i
            local plg = v
            local w_entry = subui.widget.CheckBox()
                :setText(plg.name)
                :setRect(0, 0, _width, _w_height)
                :setCallback(function (value)
                    lstg.plugin.SaveConfig(self.plugins)
                end, function ()
                    return plg.enable
                end, function (value)
                    plg.enable = value
                end)
            table.insert(ws_, w_entry)
        end
        self._view:setWidgets(ws_)
        self._view._index = 1
    end

    self:refresh()
    self:_updateLayout() -- 先更新一次
end

function PluginManager:frame()
    task.Do(self)
    self:_updateLayout()
    if not self.locked then
        if self.exit_func and (subui.keyboard.cancel.down or subui.mouse.xbutton1.down) then
            self.exit_func()
        end
    end
    self._back:update(not self.locked and subui.isMouseInRect(self._back))
    self._view:update(not self.locked)
end

function PluginManager:render()
    if self.alpha0 >= 0.0001 then
        SetViewMode("ui")
        local y = self.y + 9.5 * 24
        subui.drawTTF("ttf:menu-font", self.title, self.x, self.x, y, y, lstg.Color(self.alpha * 255, 255, 255, 255), "center", "vcenter")
        self._back:draw()
        self._view:draw()
        SetViewMode("world")
    end
end

---@param exit_f fun()
---@return launcher.menu.PluginManager
function PluginManager.create(exit_f)
    return lstg.New(PluginManager, exit_f)
end

--------------------------------------------------------------------------------

--- 启动器场景
local stage_launcher = stage.New('launcher_scene', true, true)
function stage_launcher:init()
    lstg.SetSplash(true)

    -- 背景
    self.color_value = 0
    self.color_value_d = 1 / 30

    -- 加载菜单资源
    subui.loadResources()

    -- 菜单栈，用来简化菜单跳转
    local empty_menu_obj = lstg.New(object)
    local menu_stack = {}
    local function menuFlyIn(self, dir)
        self.alpha = 1
        if dir == 'left' then
            self.x = screen.width * 0.5 - screen.width
        elseif dir == 'right' then
            self.x = screen.width * 0.5 + screen.width
        end
        task.Clear(self)
        task.New(self, function()
            task.MoveTo(screen.width * 0.5, self.y, 30, 2)
            self.locked = false
        end)
        task.New(self, function()
            for i = 1, 30 do
                self.alpha0 = i / 30
                task.Wait(1)
            end
        end)
    end
    local function menuFlyOut(self, dir)
        local x
        if dir == 'left' then
            x = screen.width * 0.5 - screen.width
        elseif dir == 'right' then
            x = screen.width * 0.5 + screen.width
        end
        task.Clear(self)
        if not self.locked then
            task.New(self, function()
                self.locked = true
                task.MoveTo(x, self.y, 30, 1)
            end)
            task.New(self, function()
                for i = 29, 0, -1 do
                    self.alpha0 = i / 30
                    task.Wait(1)
                end
            end)
        end
    end
    local function pushMenuStack(obj)
        obj = obj or empty_menu_obj
        if #menu_stack > 0 then
            menuFlyOut(menu_stack[#menu_stack], 'left')
        end
        table.insert(menu_stack, obj)
        menuFlyIn(obj, 'right')
    end
    local function popMenuStack()
        if #menu_stack > 0 then
            menuFlyOut(menu_stack[#menu_stack], 'right')
            table.remove(menu_stack)
        end
        if #menu_stack > 0 then
            menuFlyIn(menu_stack[#menu_stack], 'left')
        end
    end
    function setMod(mod_name)
        setting.mod = mod_name
        saveConfigure()
        pushMenuStack(nil)
        self.color_value_d = -1 / 30
        task.New(self, function()
            task.Wait(30)
            stage.Set("launcher_loading_scene", "none")
        end)
    end

    -- Mod 选择菜单
    local menu_mod = SelectMod.create(function()
        subui.sound.playConfirm()
        popMenuStack()
    end)

    -- 文本输入
    local menu_textinput = TextInput.create()

    -- 按键设置菜单
    local menu_key_setting = InputSetting.create(function()
        popMenuStack()
    end)

    -- 设置菜单
    local menu_setting = GameSetting.create(function()
        popMenuStack()
    end)

    -- 插件管理菜单
    local menu_plugin = PluginManager.create(function()
        popMenuStack()
    end)

    -- 一级菜单
    ---@type launcher.menu.MainMenu
    local menu_main
    local function exitGame()
        subui.sound.playCancel()
        popMenuStack()
        self.color_value_d = -1 / 30
        task.New(self, function()
            task.Wait(30)
            stage.QuitGame()
        end)
    end
    local function exitMain()
        if menu_main._view._index == #menu_main._view._widget then
            exitGame()
        else
            menu_main._view:setCursorIndex(#menu_main._view._widget)
        end
    end
    menu_main = Main.create(exitMain, {
        { "launcher.menu.start", function()
            subui.sound.playConfirm()
            menu_mod:refresh()
            pushMenuStack(menu_mod)
        end },
        { "launcher.menu.username", function()
            subui.sound.playConfirm()
            menu_textinput:reset("launcher.menu.username", setting.username, function(text)
                if text then
                    setting.username = text
                    saveConfigure()
                end
                popMenuStack()
            end)
            pushMenuStack(menu_textinput)
        end },
        { "launcher.menu.setting.input.keyboard", function()
            subui.sound.playConfirm()
            menu_key_setting:refresh()
            pushMenuStack(menu_key_setting)
        end },
        { "launcher.menu.setting.game", function()
            subui.sound.playConfirm()
            menu_setting:refresh()
            pushMenuStack(menu_setting)
        end },
        { "launcher.menu.plugin_manager", function()
            subui.sound.playConfirm()
            menu_plugin:refresh()
            pushMenuStack(menu_plugin)
        end },
        { "$lang", function() end }, -- 被自己的代码丑到了……
        { "launcher.menu.exit", exitGame },
    })

    -- 开始场景
    subui.sound.playConfirm()
    pushMenuStack(menu_main)
end
function stage_launcher:frame()
    subui.updateInput()
    self.color_value = math.max(0, math.min(self.color_value + self.color_value_d, 1))
end
function stage_launcher:render()
    subui.updateResources()
    SetViewMode("ui")
    local rgb = 16 * self.color_value
    RenderClearViewMode(lstg.Color(255, rgb, rgb, rgb))
    SetViewMode("world")
end

--- 这个场景未来应该可以写一个加载动画
local stage_launcher_loading = stage.New('launcher_loading_scene', false, true)
function stage_launcher_loading:init()
    if lstg.FileManager and lstg.FileManager.AddSearchPath then
        if lstg.FileManager.FileExist(string.format("mod/%s.zip", setting.mod)) then
            lstg.LoadPack(string.format("mod/%s.zip", setting.mod))
        else
            lstg.FileManager.AddSearchPath(string.format("mod/%s/", setting.mod))
        end
    else
        lstg.LoadPack(string.format("mod/%s.zip", setting.mod))
    end

    lstg.SetSplash(false)
    lstg.SetTitle(setting.mod)
    --lstg.SetSEVolume(setting.sevolume / 100)
    --lstg.SetBGMVolume(setting.bgmvolume / 100)
    --if not lstg.ChangeVideoMode(setting.resx, setting.resy, setting.windowed, setting.vsync) then
    --    setting.windowed = true
    --    saveConfigure()
    --    if not lstg.ChangeVideoMode(setting.resx, setting.resy, setting.windowed, setting.vsync) then
    --        stage.QuitGame()
    --        return
    --    end
    --end
    --ResetScreen()

    lstg.SetResourceStatus("global")
    Include("root.lua")
    lstg.plugin.DispatchEvent("afterMod")
    InitAllClass()
    lstg.SetResourceStatus("stage")

    InitScoreData()
    ext.reload()
    stage.Set("init", "none")
end

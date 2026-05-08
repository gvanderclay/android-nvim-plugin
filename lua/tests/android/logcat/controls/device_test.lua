local M = {}

local assert = require("tests.helpers.assert")
local logcat_helpers = require("tests.helpers.logcat_controls")
local stubs_helper = require("tests.helpers.stubs")

local function state_with_device(serial)
  return logcat_helpers.build_state({
    logcat = {
      package = "com.saved",
      filter = "",
      serial = serial,
    },
  })
end

local function device_picker_stubs(serial)
  return {
    ["android.devices.adb"] = {
      list = function()
        return {
          { serial = "device-1", state = "device" },
          { serial = "emulator-5554", state = "device", model = "Pixel_8" },
        }
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        assert.eq(opts.title, "Select logcat device", "device picker title")
        opts.on_select(serial)
      end,
    },
  }
end

local function device_change_restarts_logcat()
  local state = state_with_device("device-1")
  local stubs = device_picker_stubs("emulator-5554")

  logcat_helpers.with_logcat_context({ state = state, stubs = stubs }, function(ctx)
    ctx.vim_state.keymaps["n"]["gd"]()
    assert.table_eq(
      { ctx.spawn_calls.count, ctx.clear_body_calls.count },
      { 2, 1 },
      "spawn after device change"
    )
  end)
end

local function device_change_persists_state()
  local state = state_with_device("device-1")
  local stubs = device_picker_stubs("emulator-5554")

  logcat_helpers.with_logcat_context({ state = state, stubs = stubs }, function(ctx)
    ctx.vim_state.keymaps["n"]["gd"]()
    assert.eq(ctx.state.logcat.serial, "emulator-5554", "device persisted")
  end)
end

local function header_enter_selects_device()
  local state = state_with_device("device-1")
  local stubs = device_picker_stubs("emulator-5554")

  logcat_helpers.with_logcat_and_enter({ state = state, stubs = stubs }, 4, function(ctx)
    assert.eq(ctx.state.logcat.serial, "emulator-5554", "header device selection")
  end)
end

local function device_fallback_uses_input_without_adb()
  local state = state_with_device("device-1")
  local stubs = stubs_helper.merge_stubs(logcat_helpers.no_adb_stubs(), {
    ["android.ui.picker"] = {
      select_from_list = function()
        error("picker should not be used when adb is unavailable")
      end,
    },
  })

  logcat_helpers.with_logcat_context({
    state = state,
    vim_opts = { input_value = "usb-1234" },
    stubs = stubs,
  }, function(ctx)
    ctx.vim_state.keymaps["n"]["gd"]()
    local call = ctx.vim_state.input_calls[1] or {}
    local summary = string.format(
      "%d|%s|%s|%s",
      #ctx.vim_state.input_calls,
      call.prompt or "",
      call.default or "",
      ctx.state.logcat.serial or ""
    )
    assert.eq(summary, "1|Logcat device: |device-1|usb-1234", "device input")
  end)
end

function M.run()
  device_change_restarts_logcat()
  device_change_persists_state()
  header_enter_selects_device()
  device_fallback_uses_input_without_adb()
end

return M

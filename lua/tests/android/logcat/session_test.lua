local M = {}

local assert = require("tests.helpers.assert")
local logcat_helpers = require("tests.helpers.logcat_controls")
local stubs_helper = require("tests.helpers.stubs")

local function pid_lookup_uses_selected_device()
  logcat_helpers.with_vim_stubs({}, function()
    local runner_calls = {}
    local stubs = {
      ["android.command.job"] = {
        spawn = function()
          return { ok = true, stop = function() end }
        end,
      },
      ["android.logcat.command"] = {
        build = function()
          return { "adb", "logcat" }
        end,
      },
      ["android.ui.panel"] = {
        open = function() end,
        clear = function() end,
        append = function() end,
        set_header_lines = function() end,
        clear_body = function() end,
        replace_body = function() end,
        trim_body = function() end,
        close = function() return true end,
      },
    }

    stubs_helper.with_stubs(stubs, function()
      package.loaded["android.logcat.session"] = nil
      local session = require("android.logcat.session")
      local instance = session.new({
        config_id = "android",
        workspace = { root = "/workspace" },
        root = "/workspace",
        origin_win = 1,
        buf = 1,
        win = 1,
        package = "com.example.app",
        filter = "",
        serial = "emulator-5554",
        adb_path = "/bin/adb",
        runner = {
          run = function(cmd)
            runner_calls[#runner_calls + 1] = cmd
            return { ok = true, stdout = "123" }
          end,
        },
        state = {},
      })

      session.start(instance)
      assert.table_eq(runner_calls[1], {
        "/bin/adb",
        "-s",
        "emulator-5554",
        "shell",
        "pidof",
        "-s",
        "com.example.app",
      }, "pid lookup command")
    end)
  end)
end

function M.run()
  pid_lookup_uses_selected_device()
end

return M

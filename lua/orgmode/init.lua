_G.org = _G.org or {}
local Config = require('orgmode.config')
local Agenda = require('orgmode.agenda')
local Capture = require('orgmode.capture')
local utils = require('orgmode.utils')
local parser = require('orgmode.parser')
local instance = nil

---@class Org
---@field agenda Agenda
---@field capture Capture
local Org = {}

function Org:new()
  local data = { files = {}, initialized = false }
  setmetatable(data, self)
  self.__index = self
  data:setup_autocmds()
  return data
end

function Org:init()
  if self.initialized then return end
  self:load()
  self.agenda = Agenda:new({ files = self.files, org = self })
  self.capture = Capture:new({ agenda = self.agenda })
  self.initialized = true
end

---@param file? string
---@return string
function Org:load(file)
  if file then
    local category = vim.fn.fnamemodify(file, ':t:r')
    return utils.readfile(file, function(err, result)
      if err then return end
      self.files[file] = parser.parse(result, category, file)
      self.agenda:update_file(file, self.files[file])
    end)
  end

  local files = Config:get_all_files()
  for _, item in ipairs(files) do
    local category = vim.fn.fnamemodify(item, ':t:r')
    utils.readfile(item, function(err, result)
      if err then return end
      self.files[item] = parser.parse(result, category, item)
      self.agenda:update_file(item, self.files[item])
    end)
  end
  return self
end

---@param file? string
---@return string
function Org:reload(file)
  self:init()
  if file then
    return self:load(file)
  end
  self.files = {}
  return self:load()
end

function Org:setup_autocmds()
  vim.cmd[[augroup orgmode_nvim]]
  vim.cmd[[autocmd!]]
  vim.cmd[[autocmd BufWritePost *.org call luaeval('require("orgmode").reload(_A)', expand('<afile>:p'))]]
  vim.cmd[[augroup END]]
end

---@param opts? table
---@return Org
local function setup(opts)
  Config = Config:extend(opts)
  instance = Org:new()
  Config:setup_mappings()
  return instance
end

---@param file? string
---@return Org
local function reload(file)
  if not instance then return end
  return instance:reload(file)
end

---@param opts table
local function action(cmd, opts)
  local parts = vim.split(cmd, '.', true)
  if not instance or #parts < 2 then return end
  instance:init()
  if instance[parts[1]] and instance[parts[1]][parts[2]] then
    local item = instance[parts[1]]
    local method = item[parts[2]]
    return method(item, opts)
  end
end

return {
  setup = setup,
  reload = reload,
  action = action,
}
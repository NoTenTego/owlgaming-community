--[[
    mysql_external_module.lua
    Compatibility layer rewritten to use MTA native dbQuery/dbPoll/dbFree
    instead of the deprecated mta_mysql.so module (removed in owlgaming-community).

    Exported function signatures are unchanged so all other resources work as-is.
]]

local resultPool   = {}
local queryPool    = {}
local lastInsertID = 0
local countqueries = 0
local sqllog       = false

-- -----------------------------------------------------------------------
-- Internal helpers
-- -----------------------------------------------------------------------

local function getConnection(db)
    -- getConn() is defined in mysql.lua (same resource, same server scope)
    return getConn(db or "mta")
end

-- Run a query synchronously and return the result table + numrows
local function runQuery(str, db)
    local conn = getConnection(db)
    if not conn then
        outputDebugString("[mysql_external] No DB connection for: " .. tostring(db))
        return nil, 0
    end
    local qh = dbQuery(conn, str)
    if not qh then
        outputDebugString("[mysql_external] dbQuery failed: " .. tostring(str))
        return nil, 0
    end
    local rows, numrows, lid = dbPoll(qh, -1)
    lastInsertID = lid or 0
    return rows or {}, numrows or 0
end

local function getFreePoolID()
    for i, v in ipairs(resultPool) do
        if v == nil then return i end
    end
    return #resultPool + 1
end

-- -----------------------------------------------------------------------
-- Legacy compatibility stubs (module no longer loaded)
-- -----------------------------------------------------------------------

function connectToDatabase(res)
    outputDebugString("[mysql_external] connectToDatabase: using native dbConnect (noop)")
end

function destroyDatabaseConnection()
    outputDebugString("[mysql_external] destroyDatabaseConnection: noop")
end

-- mysql_null() was used to insert SQL NULL values
function mysql_null()
    return nil
end

-- -----------------------------------------------------------------------
-- Getters (legacy)
-- -----------------------------------------------------------------------

function getMySQLUsername() return username end
function getMySQLPassword() return password end
function getMySQLDBName()   return database end
function getMySQLHost()     return hostname end
function getMySQLPort()     return port     end
function getForumsPrefix()  return externalprefix end

-- -----------------------------------------------------------------------
-- Core exported functions
-- -----------------------------------------------------------------------

function ping()
    -- dbConnect uses autoreconnect=1, always return true
    return true
end

function escape_string(str)
    if not str then return "" end
    str = tostring(str)
    str = str:gsub("\\", "\\\\")
    str = str:gsub("'",  "\\'")
    str = str:gsub('"',  '\\"')
    str = str:gsub("\0", "\\0")
    str = str:gsub("\n", "\\n")
    str = str:gsub("\r", "\\r")
    str = str:gsub("\26","\\Z")
    return str
end

function query(str)
    countqueries = countqueries + 1
    if sqllog then outputDebugString("[SQL] " .. str) end

    local rows, _ = runQuery(str, "mta")
    if rows == nil then return false end

    local id = getFreePoolID()
    resultPool[id] = { rows = rows, cursor = 1 }
    queryPool[id]  = str
    return id
end

function unbuffered_query(str)
    -- MTA dbQuery is always buffered; treat identically to query()
    return query(str)
end

function fetch_assoc(resultid)
    local entry = resultPool[resultid]
    if not entry then return false end
    local row = entry.rows[entry.cursor]
    if not row then return false end
    entry.cursor = entry.cursor + 1
    return row
end

function rows_assoc(resultid)
    local entry = resultPool[resultid]
    if not entry then return false end
    return entry.rows
end

function free_result(resultid)
    if not resultPool[resultid] then return false end
    resultPool[resultid] = nil
    queryPool[resultid]  = nil
    return nil
end

function num_rows(resultid)
    local entry = resultPool[resultid]
    if not entry then return false end
    return #entry.rows
end

function insert_id()
    return lastInsertID or false
end

-- Compound helpers
function query_free(str)
    local id = query(str)
    if id == false then return false end
    free_result(id)
    return true
end

function query_fetch_assoc(str)
    local id = query(str)
    if id == false then return false end
    local row = fetch_assoc(id)
    free_result(id)
    return row
end

function query_rows_assoc(str)
    local id = query(str)
    if id == false then return false end
    local rows = rows_assoc(id)
    free_result(id)
    return rows
end

function query_insert_free(str)
    local id = query(str)
    if id == false then return false end
    local lid = insert_id()
    free_result(id)
    return lid
end

-- -----------------------------------------------------------------------
-- Forum (core DB) queries
-- -----------------------------------------------------------------------

function forumQuery(str)
    countqueries = countqueries + 1
    if sqllog then outputDebugString("[SQL-core] " .. str) end

    local rows, _ = runQuery(str, "core")
    if rows == nil then return false end

    local id = getFreePoolID()
    resultPool[id] = { rows = rows, cursor = 1 }
    queryPool[id]  = str
    return id
end

function forum_query_fetch_assoc(str)
    local id = forumQuery(str)
    if id == false then return false end
    local row = fetch_assoc(id)
    free_result(id)
    return row
end

function forum_query_free(str)
    local id = forumQuery(str)
    if id == false then return false end
    free_result(id)
    return true
end

function forum_query_insert_free(str)
    local id = forumQuery(str)
    if id == false then return false end
    local lid = insert_id()
    free_result(id)
    return lid
end

-- -----------------------------------------------------------------------
-- Debug helpers
-- -----------------------------------------------------------------------

function debugMode()
    sqllog = not sqllog
    return sqllog
end

function returnQueryStats()
    return countqueries
end

function getOpenQueryStr(resultid)
    if not queryPool[resultid] then return false end
    return queryPool[resultid]
end

addCommandHandler("testdb",
    function(thePlayer)
        if exports.global:isPlayerScripter(thePlayer) then
            local conn = getConnection("mta")
            if conn then
                outputChatBox("Main DB: online (native dbConnect)", thePlayer, 0, 255, 0)
            else
                outputChatBox("Main DB: offline", thePlayer, 255, 0, 0)
            end
        end
    end, false, false
)

addCommandHandler("mysqlleaky",
    function(thePlayer)
        if exports.global:isPlayerScripter(thePlayer) then
            local count = 0
            for _ in pairs(queryPool) do count = count + 1 end
            outputChatBox("#queryPool=" .. tostring(count), thePlayer)
        end
    end
)

-- -----------------------------------------------------------------------
-- High-level CRUD helpers (select/insert/update/delete)
-- -----------------------------------------------------------------------

local function createWhereClause(array, required)
    if not array then
        return not required and "" or nil
    end
    local parts = {}
    for col, val in pairs(array) do
        table.insert(parts, "`" .. col .. "` = '" .. (tonumber(val) or escape_string(val)) .. "'")
    end
    return " WHERE " .. table.concat(parts, " AND ")
end

function select(tableName, clause)
    local rows = {}
    local id = query("SELECT * FROM " .. tableName .. createWhereClause(clause))
    if id then
        while true do
            local row = fetch_assoc(id)
            if not row then break end
            table.insert(rows, row)
        end
        free_result(id)
        return rows
    end
    return false
end

function select_one(tableName, clause)
    local id = query("SELECT * FROM " .. tableName .. createWhereClause(clause) .. " LIMIT 1")
    if id then
        local row = fetch_assoc(id)
        free_result(id)
        return row
    end
    return false
end

function insert(tableName, array)
    local keys, vals = {}, {}
    for col, val in pairs(array) do
        table.insert(keys, col)
        table.insert(vals, tonumber(val) or escape_string(val))
    end
    local sql = "INSERT INTO `" .. tableName .. "` (`" ..
        table.concat(keys, "`, `") .. "`) VALUES ('" ..
        table.concat(vals, "', '") .. "')"
    return query_insert_free(sql)
end

function update(tableName, array, clause)
    local parts = {}
    for col, val in pairs(array) do
        if val == nil then
            table.insert(parts, "`" .. col .. "` = NULL")
        else
            table.insert(parts, "`" .. col .. "` = '" .. (tonumber(val) or escape_string(val)) .. "'")
        end
    end
    local sql = "UPDATE `" .. tableName .. "` SET " ..
        table.concat(parts, ", ") .. createWhereClause(clause, true)
    return query_free(sql)
end

function delete(tableName, clause)
    return query_free("DELETE FROM " .. tableName .. createWhereClause(clause, true))
end

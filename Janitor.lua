local Janitor = {}
Janitor.ClassName = "Janitor"
Janitor.__index = Janitor

function Janitor.Is(Object)
    return type(Object) == "table" and Object.ClassName == "Janitor"
end

function Janitor.new()
    return setmetatable({
        _tasks = {},
        _links = {}
    }, Janitor)
end

function Janitor:__call()
    self:Cleanup()
end

function Janitor:Add(Object, MethodName, Index)
    if Index then
        self:Remove(Index)
    end

    local CleanupMethod = MethodName
    if not CleanupMethod then
        if type(Object) == "function" or type(Object) == "thread" then
            CleanupMethod = true
        elseif typeof(Object) == "RBXScriptConnection" then
            CleanupMethod = "Disconnect"
        elseif typeof(Object) == "Instance" then
            CleanupMethod = "Destroy"
        elseif type(Object) == "table" then
            if type(Object.Destroy) == "function" then
                CleanupMethod = "Destroy"
            elseif type(Object.Disconnect) == "function" then
                CleanupMethod = "Disconnect"
            elseif type(Object.cancel) == "function" then
                CleanupMethod = "cancel"
            elseif type(Object.Cancel) == "function" then
                CleanupMethod = "Cancel"
            end
        end
    end

    local taskIndex = Index or Object
    self._tasks[taskIndex] = {
        Object = Object,
        MethodName = CleanupMethod
    }

    return Object
end

function Janitor:Remove(Index)
    local TaskData = self._tasks[Index]
    if TaskData then
        local Object = TaskData.Object
        local Method = TaskData.MethodName

        self._tasks[Index] = nil 

        if Method == true then
            if type(Object) == "function" then
                Object()
            elseif type(Object) == "thread" then
                task.cancel(Object)
            end
        elseif type(Method) == "string" then
            Object[Method](Object)
        elseif type(Method) == "function" then
            Method(Object)
        end
    end
    return self
end

function Janitor:RemoveNoClean(Index)
    self._tasks[Index] = nil
    return self
end

function Janitor:Get(Index)
    local TaskData = self._tasks[Index]
    return TaskData and TaskData.Object or nil
end

function Janitor:Cleanup()
    for Index, _ in pairs(self._tasks) do
        self:Remove(Index)
    end
end

function Janitor:LinkToInstance(Object, AllowMultiple)
    if typeof(Object) ~= "Instance" then
        error("Janitor: LinkToInstance requer uma Instance válida do Roblox.", 2)
    end

    local connection = Object.Destroying:Connect(function()
        self:Cleanup()
    end)

    if not AllowMultiple then
        for _, link in pairs(self._links) do
            link:Disconnect()
        end
        table.clear(self._links)
    end

    table.insert(self._links, connection)
    
    self:Add(connection, "Disconnect", connection)
    
    return self
end

function Janitor:Destroy()
    self:Cleanup()
    for _, link in pairs(self._links) do
        link:Disconnect()
    end
    table.clear(self._links)
    setmetatable(self, nil)
end

return Janitor

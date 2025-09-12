getgenv().filtergc = newcclosure(function(filterType, filterOptions, returnOne)
	local matches = {}

    if typeof(filterType) == "function" then
        local matches = {}
        
        for i, v in getgc(true) do
            local success, passed = pcall(filterType, v)
            if success and passed then
				if returnOne then
					return v
				else
                	table.insert(matches, v)
				end
            end
        end

	elseif filterType == "table" then
        for i, v in getgc(true) do
            if typeof(v) ~= "table" then
                continue
            end
            
            local passed = true
            
            if filterOptions.Keys and typeof(filterOptions.Keys) == "table" and passed then
                for _, key in filterOptions.Keys do
                    if rawget(v, key) == nil then
                        passed = false
                        break
                    end
                end
            end
            
            if filterOptions.Values and typeof(filterOptions.Values) == "table" and passed then
                local tableVals = {}
                for _, value in next, v do
                    table.insert(tableVals, value)
                end
                for _, value in filterOptions.Values do
                    if not table.find(tableVals, value) then
                        passed = false
                        break
                    end
                end
            end
            if filterOptions.KeyValuePairs and typeof(filterOptions.KeyValuePairs) == "table" and passed then
                for key, value in filterOptions.KeyValuePairs do
                    if rawget(v, key) ~= value then
                        passed = false
                        break
                    end
                end
            end
            
            if filterOptions.Metatable and passed then
                local success, mt = pcall(getrawmetatable, v)
                if success then
                    passed = filterOptions.Metatable == mt
                else
                    passed = false
                end
            end
            
            if passed then
                if returnOne then
                    return v
                else
                    table.insert(matches, v)
                end
            end
        end
        
    elseif filterType == "function" then
        if filterOptions.IgnoreExecutor == nil then
            filterOptions.IgnoreExecutor = true
        end
        
        for i, v in getgc(false) do
            if typeof(v) ~= "function" then
                continue
            end
            
            local passed = true
            local isCClosure = iscclosure(v)

            if filterOptions.Name and passed then
                local success, funcName = pcall(function()
                    return debug.info(v, "n")
                end)

                if success and funcName then
                    passed = funcName == filterOptions.Name
                else
                    local success2, funcString = pcall(function()
                        return tostring(v)
                    end)
                    if success2 and funcString then
                        passed = string.find(funcString, filterOptions.Name) ~= nil
                    else
                        passed = false
                    end
                end
            end
            
            if filterOptions.IgnoreExecutor == true and passed then
                local success, isExec = pcall(function() return isexecutorclosure(v) end)
                if success then
                    passed = not isExec
                else
                    passed = true
                end
            end

            if isCClosure and (filterOptions.Hash or filterOptions.Constants or filterOptions.Upvalues) then
                passed = false
            end

            if not isCClosure and passed then
                if filterOptions.Hash and passed then
                    local success, hash = pcall(function()
                        return getfunctionhash(v) or ""
                    end)
                    if success and hash then
                        passed = hash == filterOptions.Hash
                    else
                        passed = false
                    end
                end
                
                if filterOptions.Constants and typeof(filterOptions.Constants) == "table" and passed then
                    local success, constants = pcall(function()
                        return debug.getconstants(v) or {}
                    end)

                    if success and constants then
                        local funcConsts = {}
                        for idx, constant in constants do
                            if constant ~= nil then
                                table.insert(funcConsts, constant)
                            end
                        end
                        for _, constant in filterOptions.Constants do
                            if not table.find(funcConsts, constant) then
                                passed = false
                                break
                            end
                        end
                    else
                        passed = false
                    end
                end
                
                if filterOptions.Upvalues and typeof(filterOptions.Upvalues) == "table" and passed then
                    local success, upvalues = pcall(function()
                        return debug.getupvalues(v) or {}
                    end)

                    if success and upvalues then
                        local funcUpvals = {}
                        for idx, upval in upvalues do
                            if upval ~= nil then
                                table.insert(funcUpvals, upval)
                            end
                        end
                        for _, upval in filterOptions.Upvalues do
                            if not table.find(funcUpvals, upval) then
                                passed = false
                                break
                            end
                        end
                    else
                        passed = false
                    end
                end
            end
            
            if passed then
                if returnOne then
                    return v
                else
                    table.insert(matches, v)
                end
            end
        end
        
    else
        error("Expected type 'function' or 'table', got '" .. tostring(filterType) .. "'")
    end
    
    return returnOne and nil or matches
end)

local drawingUI = nil
task.spawn(function()
	repeat task.wait() until getgenv().Instance and getgenv().game
	drawingUI = getgenv().Instance.new("ScreenGui", getgenv().game:GetService("CoreGui"))
	drawingUI.Name = "Drawing"
	drawingUI.IgnoreGuiInset = true
	drawingUI.DisplayOrder = 0x7fffffff
end)

local drawingIndex = 0

local function safeDestroy(obj)
	if obj and obj.Destroy then pcall(function() obj:Destroy() end) end
end

local baseDrawingObj = setmetatable({
	Visible = true,
	ZIndex = 0,
	Transparency = 1,
	Color = Color3.new(),
	Remove = function(self) setmetatable(self, nil) end,
	Destroy = function(self) setmetatable(self, nil) end
}, {
	__add = function(t1, t2)
		local result = table.clone(t1)
		for i,v in t2 do result[i] = v end
		return result
	end
})

local drawingFontsEnum = {
	[0] = Font.fromEnum(Enum.Font.Roboto),
	[1] = Font.fromEnum(Enum.Font.Legacy),
	[2] = Font.fromEnum(Enum.Font.SourceSans),
	[3] = Font.fromEnum(Enum.Font.RobotoMono),
}

local function convertTransparency(t) return math.clamp(1 - t, 0, 1) end

local DrawingLib = {}
DrawingLib.Fonts = { UI=0, System=1, Plex=2, Monospace=3 }

function DrawingLib.new(drawingType)
	drawingIndex += 1

	-- LINE
	if drawingType == "Line" then
		local obj = ({ From=Vector2.zero, To=Vector2.zero, Thickness=1 } + baseDrawingObj)
		local frame = getgenv().Instance.new("Frame")
		frame.Name = drawingIndex
		frame.AnchorPoint = Vector2.one * .5
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = obj.Color
		frame.Visible = obj.Visible
		frame.ZIndex = obj.ZIndex
		frame.BackgroundTransparency = convertTransparency(obj.Transparency)
		frame.Parent = drawingUI

		return setmetatable({__type="Drawing Object"}, {
			__newindex = function(_, i, v)
				if typeof(obj[i]) == "nil" then return end
				if i=="From" or i=="To" then
					local a = (i=="From" and v or obj.From)
					local b = (i=="To" and v or obj.To)
					local dir = b - a
					local center = (a+b)/2
					frame.Position = UDim2.fromOffset(center.X, center.Y)
					frame.Rotation = math.deg(math.atan2(dir.Y, dir.X))
					frame.Size = UDim2.fromOffset(dir.Magnitude, obj.Thickness)
				elseif i=="Thickness" then
					frame.Size = UDim2.fromOffset((obj.To-obj.From).Magnitude, v)
				elseif i=="Visible" then frame.Visible=v
				elseif i=="ZIndex" then frame.ZIndex=v
				elseif i=="Transparency" then frame.BackgroundTransparency=convertTransparency(v)
				elseif i=="Color" then frame.BackgroundColor3=v
				end
				obj[i]=v
			end,
			__index = function(self,i)
				if i=="Remove" or i=="Destroy" then
					return function() safeDestroy(frame); obj.Remove(self); return obj:Remove() end
				end
				return obj[i]
			end,
			__tostring=function() return "Drawing" end
		})

	-- TEXT
	elseif drawingType == "Text" then
		local obj = ({
			Text="", Font=DrawingLib.Fonts.UI, Size=0, Position=Vector2.zero,
			Center=false, Outline=false, OutlineColor=Color3.new()
		} + baseDrawingObj)
		local label, stroke = getgenv().Instance.new("TextLabel"), getgenv().Instance.new("UIStroke")
		label.Name = drawingIndex
		label.AnchorPoint = Vector2.one * .5
		label.BorderSizePixel=0
		label.BackgroundTransparency=1
		label.Visible=obj.Visible
		label.TextColor3=obj.Color
		label.TextTransparency=convertTransparency(obj.Transparency)
		label.ZIndex=obj.ZIndex
		label.FontFace=drawingFontsEnum[obj.Font]
		label.TextSize=obj.Size
		stroke.Thickness=1
		stroke.Enabled=obj.Outline
		stroke.Color=obj.OutlineColor
		stroke.Parent=label
		label.Parent=drawingUI

		label:GetPropertyChangedSignal("TextBounds"):Connect(function()
			local b=label.TextBounds; local o=b/2
			label.Size=UDim2.fromOffset(b.X,b.Y)
			label.Position=UDim2.fromOffset(obj.Position.X+(obj.Center and 0 or o.X), obj.Position.Y+o.Y)
		end)

		return setmetatable({__type="Drawing Object"}, {
			__newindex=function(_,i,v)
				if typeof(obj[i])=="nil" then return end
				if i=="Text" then label.Text=v
				elseif i=="Font" then label.FontFace=drawingFontsEnum[math.clamp(v,0,3)]
				elseif i=="Size" then label.TextSize=v
				elseif i=="Position" then
					local o=label.TextBounds/2
					label.Position=UDim2.fromOffset(v.X+(obj.Center and 0 or o.X), v.Y+o.Y)
				elseif i=="Center" then
					local pos=(v and workspace.CurrentCamera.ViewportSize/2 or obj.Position)
					label.Position=UDim2.fromOffset(pos.X,pos.Y)
				elseif i=="Outline" then stroke.Enabled=v
				elseif i=="OutlineColor" then stroke.Color=v
				elseif i=="Visible" then label.Visible=v
				elseif i=="ZIndex" then label.ZIndex=v
				elseif i=="Transparency" then
					local t=convertTransparency(v); label.TextTransparency=t; stroke.Transparency=t
				elseif i=="Color" then label.TextColor3=v
				end
				obj[i]=v
			end,
			__index=function(self,i)
				if i=="Remove" or i=="Destroy" then
					return function() safeDestroy(label); obj.Remove(self); return obj:Remove() end
				elseif i=="TextBounds" then return label.TextBounds end
				return obj[i]
			end,
			__tostring=function() return "Drawing" end
		})

	-- CIRCLE
	elseif drawingType == "Circle" then
		local obj = ({ Radius=150, Position=Vector2.zero, Thickness=.7, Filled=false } + baseDrawingObj)
		local frame,corner,stroke = getgenv().Instance.new("Frame"), getgenv().Instance.new("UICorner"), getgenv().Instance.new("UIStroke")
		frame.Name=drawingIndex
		frame.AnchorPoint=Vector2.one*.5
		frame.BorderSizePixel=0
		frame.BackgroundTransparency=(obj.Filled and convertTransparency(obj.Transparency) or 1)
		frame.BackgroundColor3=obj.Color
		frame.Visible=obj.Visible
		frame.ZIndex=obj.ZIndex
		corner.CornerRadius=UDim.new(1,0)
		frame.Size=UDim2.fromOffset(obj.Radius,obj.Radius)
		stroke.Thickness=obj.Thickness
		stroke.Enabled=not obj.Filled
		stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
		corner.Parent=frame; stroke.Parent=frame; frame.Parent=drawingUI

		return setmetatable({__type="Drawing Object"}, {
			__newindex=function(_,i,v)
				if typeof(obj[i])=="nil" then return end
				if i=="Radius" then frame.Size=UDim2.fromOffset(v*2,v*2)
				elseif i=="Position" then frame.Position=UDim2.fromOffset(v.X,v.Y)
				elseif i=="Thickness" then stroke.Thickness=math.clamp(v,.6,1e9)
				elseif i=="Filled" then frame.BackgroundTransparency=(v and convertTransparency(obj.Transparency) or 1); stroke.Enabled=not v
				elseif i=="Visible" then frame.Visible=v
				elseif i=="ZIndex" then frame.ZIndex=v
				elseif i=="Transparency" then local t=convertTransparency(v); frame.BackgroundTransparency=(obj.Filled and t or 1); stroke.Transparency=t
				elseif i=="Color" then frame.BackgroundColor3=v; stroke.Color=v
				end
				obj[i]=v
			end,
			__index=function(self,i)
				if i=="Remove" or i=="Destroy" then
					return function() safeDestroy(frame); obj.Remove(self); return obj:Remove() end
				end
				return obj[i]
			end,
			__tostring=function() return "Drawing" end
		})

	-- SQUARE
	elseif drawingType == "Square" then
		local obj = ({ Size=Vector2.zero, Position=Vector2.zero, Thickness=.7, Filled=false } + baseDrawingObj)
		local frame,stroke = getgenv().Instance.new("Frame"), getgenv().Instance.new("UIStroke")
		frame.Name=drawingIndex
		frame.BorderSizePixel=0
		frame.BackgroundTransparency=(obj.Filled and convertTransparency(obj.Transparency) or 1)
		frame.ZIndex=obj.ZIndex
		frame.BackgroundColor3=obj.Color
		frame.Visible=obj.Visible
		stroke.Thickness=obj.Thickness
		stroke.Enabled=not obj.Filled
		stroke.LineJoinMode=Enum.LineJoinMode.Miter
		stroke.Parent=frame; frame.Parent=drawingUI

		return setmetatable({__type="Drawing Object"}, {
			__newindex=function(_,i,v)
				if typeof(obj[i])=="nil" then return end
				if i=="Size" then frame.Size=UDim2.fromOffset(v.X,v.Y)
				elseif i=="Position" then frame.Position=UDim2.fromOffset(v.X,v.Y)
				elseif i=="Thickness" then stroke.Thickness=math.clamp(v,.6,1e9)
				elseif i=="Filled" then frame.BackgroundTransparency=(v and convertTransparency(obj.Transparency) or 1); stroke.Enabled=not v
				elseif i=="Visible" then frame.Visible=v
				elseif i=="ZIndex" then frame.ZIndex=v
				elseif i=="Transparency" then local t=convertTransparency(v); frame.BackgroundTransparency=(obj.Filled and t or 1); stroke.Transparency=t
				elseif i=="Color" then stroke.Color=v; frame.BackgroundColor3=v
				end
				obj[i]=v
			end,
			__index=function(self,i)
				if i=="Remove" or i=="Destroy" then
					return function() safeDestroy(frame); obj.Remove(self); return obj:Remove() end
				end
				return obj[i]
			end,
			__tostring=function() return "Drawing" end
		})

	-- IMAGE
	elseif drawingType == "Image" then
		local obj = ({ Data="", Size=Vector2.zero, Position=Vector2.zero } + baseDrawingObj)
		local frame=getgenv().Instance.new("ImageLabel")
		frame.Name=drawingIndex
		frame.BorderSizePixel=0
		frame.ScaleType=Enum.ScaleType.Stretch
		frame.BackgroundTransparency=1
		frame.Visible=obj.Visible
		frame.ZIndex=obj.ZIndex
		frame.ImageTransparency=convertTransparency(obj.Transparency)
		frame.ImageColor3=obj.Color
		frame.Parent=drawingUI

		return setmetatable({__type="Drawing Object"}, {
			__newindex=function(_,i,v)
				if typeof(obj[i])=="nil" then return end
				if i=="Data" then frame.Image=v
				elseif i=="Size" then frame.Size=UDim2.fromOffset(v.X,v.Y)
				elseif i=="Position" then frame.Position=UDim2.fromOffset(v.X,v.Y)
				elseif i=="Visible" then frame.Visible=v
				elseif i=="ZIndex" then frame.ZIndex=v
				elseif i=="Transparency" then frame.ImageTransparency=convertTransparency(v)
				elseif i=="Color" then frame.ImageColor3=v
				end
				obj[i]=v
			end,
			__index=function(self,i)
				if i=="Remove" or i=="Destroy" then
					return function() safeDestroy(frame); obj.Remove(self); return obj:Remove() end
				end
				return obj[i]
			end,
			__tostring=function() return "Drawing" end
		})

	-- QUAD
	elseif drawingType == "Quad" then
		local obj = ({ Thickness=1, PointA=Vector2.zero, PointB=Vector2.zero, PointC=Vector2.zero, PointD=Vector2.zero, Filled=false } + baseDrawingObj)
		local A=DrawingLib.new("Line") local B=DrawingLib.new("Line") local C=DrawingLib.new("Line") local D=DrawingLib.new("Line")

		return setmetatable({__type="Drawing Object"}, {
			__newindex=function(_,i,v)
				if i=="Thickness" then A.Thickness=v;B.Thickness=v;C.Thickness=v;D.Thickness=v
				elseif i=="PointA" then A.From=v;B.To=v
				elseif i=="PointB" then B.From=v;C.To=v
				elseif i=="PointC" then C.From=v;D.To=v
				elseif i=="PointD" then D.From=v;A.To=v
				elseif i=="Visible" then A.Visible=v;B.Visible=v;C.Visible=v;D.Visible=v
				elseif i=="Filled" then A.BackgroundTransparency=1;B.BackgroundTransparency=1;C.BackgroundTransparency=1;D.BackgroundTransparency=1
				elseif i=="Color" then A.Color=v;B.Color=v;C.Color=v;D.Color=v
				elseif i=="ZIndex" then A.ZIndex=v;B.ZIndex=v;C.ZIndex=v;D.ZIndex=v end
				obj[i]=v
			end,
			__index=function(self,i)
				if i=="Remove" or i=="Destroy" then
					return function() A:Remove();B:Remove();C:Remove();D:Remove(); obj.Remove(self); return obj:Remove() end
				end
				return obj[i]
			end,
			__tostring=function() return "Drawing" end
		})

	-- TRIANGLE
	elseif drawingType == "Triangle" then
		local obj = ({ PointA=Vector2.zero, PointB=Vector2.zero, PointC=Vector2.zero, Thickness=1, Filled=false } + baseDrawingObj)
		local lines={A=DrawingLib.new("Line"),B=DrawingLib.new("Line"),C=DrawingLib.new("Line")}
		return setmetatable({__type="Drawing Object"}, {
			__newindex=function(_,i,v)
				if typeof(obj[i])=="nil" then return end
				if i=="PointA" then lines.A.From=v;lines.B.To=v
				elseif i=="PointB" then lines.B.From=v;lines.C.To=v
				elseif i=="PointC" then lines.C.From=v;lines.A.To=v
				elseif (i=="Thickness" or i=="Visible" or i=="Color" or i=="ZIndex") then
					for _,l in lines do l[i]=v end
				elseif i=="Filled" then for _,l in lines do l.BackgroundTransparency=1 end
				end
				obj[i]=v
			end,
			__index=function(self,i)
				if i=="Remove" or i=="Destroy" then
					return function() for _,l in lines do l:Remove() end; obj.Remove(self); return obj:Remove() end
				end
				return obj[i]
			end,
			__tostring=function() return "Drawing" end
		})
	end
end

getgenv().Drawing=DrawingLib
getgenv().isrenderobj=function(o) local s,r=pcall(function() return o.__type=="Drawing Object" end) return s and r end
getgenv().cleardrawcache=function() if drawingUI then drawingUI:ClearAllChildren() end end
getgenv().getrenderproperty=function(o,p) assert(getgenv().isrenderobj(o),"Object must be a Drawing") return o[p] end
getgenv().setrenderproperty=function(o,p,v) assert(getgenv().isrenderobj(o),"Object must be a Drawing") o[p]=v end

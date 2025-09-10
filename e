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

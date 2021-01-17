local Components	= script:FindFirstAncestor("Components")
local Roact			= require(Components.Roact)
local assign		= require(Components.Roact.assign)
local Theme			= require(Components.Common.Plugin.Theme)
local Markdown		= require(script.Markdown)

local AutoText		= Roact.PureComponent:extend("DynamicTextLabel")
local AutoCode		= Roact.PureComponent:extend("DynamicCodeLabel")

function AutoText:init()
	self.state = { height = 0 }
	self.boundsChanged = function (rbx)
		self:setState({ height = rbx.TextBounds.Y })
	end
end

function AutoText:render()
	return Roact.createElement("TextLabel", assign({
		Size = UDim2.new(1, 0, 0, self.state.height),
		TextWrapped = true,
		[Roact.Change.TextBounds] = self.boundsChanged
	}, self.props))
end

function AutoCode:init()
	self.state = { bounds = Vector2.new(0, 0) }
	self.boundsChanged = function (rbx)
		self:setState({ bounds = rbx.TextBounds })
	end
end

function AutoCode:render()
	local height = self.state.bounds.Y + 24
	return Roact.createElement("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, height > 320 and 300 or height),
		Position = self.props.Position,
		BackgroundColor3 = self.props.BackgroundColor3,
		BorderColor3 = self.props.BorderColor3,
		LayoutOrder = self.props.LayoutOrder,
		BorderMode = Enum.BorderMode.Inset,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		CanvasSize = UDim2.fromOffset(self.state.bounds.X + 24, height)
	}, {
		Code = Roact.createElement("TextLabel", assign({
			Text = self.props.Text,
			TextSize = self.props.TextSize,
			TextColor3 = self.props.TextColor3,
			Font = self.props.Font,
			RichText = true,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(12, 12),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, -24, 1, -24),
			[Roact.Change.TextBounds] = self.boundsChanged
		}))
	})
end

return function (props)
	return Theme.apply(function (theme)
		local document = {}
		
		local i = 0
		for blockType, block in Markdown.parse(props.Markdown) do
			i = i + 1
			
			if blockType == Markdown.BlockType.Paragraph then
				document[i] = Roact.createElement(AutoText, {
					BackgroundTransparency = 1,
					RichText = true,
					Text = block.Text,
					TextSize = 18,
					TextColor3 = theme.Studio.Color.MainText,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					Font = theme.Font,
					LayoutOrder = i
				})
			elseif blockType == Markdown.BlockType.Heading then
				local height = 42 - block.Level * 6
				document[i] = Roact.createElement(AutoText, {
					BackgroundTransparency = 1,
					RichText = true,
					Text = "<b><uc>" .. block.Text .. "</uc></b>",
					TextSize = height,
					TextColor3 = theme.Studio.Color.MainText,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					Font = theme.Font,
					LayoutOrder = i
				})
			elseif blockType == Markdown.BlockType.Code then
				document[i] = Roact.createElement(AutoCode, {
					BackgroundColor3 = theme.Studio.Color.ScriptBackground,
					BorderColor3 = theme.Studio.Color.Border,
					Text = block.Code,
					TextSize = 18,
					TextColor3 = theme.Studio.Color.ScriptText,
					Font = Enum.Font.RobotoMono,
					LayoutOrder = i
				})
			elseif blockType == Markdown.BlockType.List then
				local text = ""
				for _, line in ipairs(block.Lines) do
					text = text .. ("  "):rep(line.Level) .. "- " .. line.Text .. "\n"
				end
				document[i] = Roact.createElement(AutoText, {
					BackgroundTransparency = 1,
					RichText = true,
					Text = text,
					TextSize = 18,
					TextColor3 = theme.Studio.Color.MainText,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					Font = theme.Font,
					LayoutOrder = i
				})
			end
			
		end
		
		return Roact.createFragment({
			Layout = Roact.createElement("UIListLayout", {
				Padding = props.Padding or UDim.new(0, 12),
				SortOrder = Enum.SortOrder.LayoutOrder,
				[Roact.Change.AbsoluteContentSize] = props[Roact.Change.AbsoluteContentSize]
			}),
			Padding = Roact.createElement("UIPadding", {
				PaddingTop = UDim.new(0, 12),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 12),
			}),
			Document = Roact.createFragment(document)
		})
	end)
end

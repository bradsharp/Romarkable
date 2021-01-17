------------------------------------------------------------------------------------------------------------------------
-- Name:		Markdown.lua
-- Version:		1.0 (1/17/2021)
-- Author:		Brad Sharp
--
-- Repository:	https://github.com/BradSharp/Romarkable
-- License:		MIT (https://github.com/BradSharp/Romarkable/blob/main/LICENSE)
--
-- Copyright (c) 2021 Brad Sharp
------------------------------------------------------------------------------------------------------------------------

local Markdown = {}

------------------------------------------------------------------------------------------------------------------------
-- Text Parser
------------------------------------------------------------------------------------------------------------------------

local InlineType = {
	Text	= 0,
	Ref		= 1,
}

local ModifierType = {
	Bold	= 0,
	Italic	= 1,
	Strike	= 2,
	Code	= 3,
}

local function sanitize(s)
	return s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("\"", "&quot;"):gsub("'", "&apos;")
end

local function characters(s)
	return s:gmatch(".")
end

local function last(t)
	return t[#t]
end

local function getModifiers(stack)
	local modifiers = {}
	for _, modifierType in pairs(stack) do
		modifiers[modifierType] = true
	end
	return modifiers
end

local function parseModifierTokens(md)
	local index = 1
	return function ()
		local text, newIndex = md:match("^([^%*_~`]+)()", index)
		if text then
			index = newIndex
			return false, text
		elseif index <= md:len() then
			local text, newIndex = md:match("^(%" .. md:sub(index, index) .. "+)()", index)
			index = newIndex
			return true, text
		end
	end
end

local function parseText(md)
	
end

local richTextLookup = {
	["*"] = ModifierType.Bold,
	["_"] = ModifierType.Italic,
	["~"] = ModifierType.Strike,
	["`"] = ModifierType.Code,
}

local function getRichTextModifierType(symbols)
	return richTextLookup[symbols:sub(1, 1)]
end

local function richText(md)
	md = sanitize(md)
	local tags = {
		[ModifierType.Bold]		= {"<b>", "</b>"},
		[ModifierType.Italic]	= {"<i>", "</i>"},
		[ModifierType.Strike]	= {"<s>", "</s>"},
		[ModifierType.Code]		= {"<font face=\"RobotoMono\">", "</font>"},
	}
	local state = {}
	local output = ""
	for token, text in parseModifierTokens(md) do
		if token then
			local modifierType = getRichTextModifierType(text)
			if state[ModifierType.Code] and modifierType ~= ModifierType.Code then
				output = output .. text
				continue
			end
			local symbolState = state[modifierType]
			if not symbolState then
				output = output .. tags[modifierType][1]
				state[modifierType] = text
			elseif text == symbolState then
				output = output .. tags[modifierType][2]
				state[modifierType] = nil
			else
				output = output .. text
			end
		else
			output = output .. text
		end
	end
	for modifierType in pairs(state) do
		output = output .. tags[modifierType][2]
	end
	return output
end

------------------------------------------------------------------------------------------------------------------------
-- Document Parser
------------------------------------------------------------------------------------------------------------------------

local BlockType = {
	None		= 0,
	Paragraph	= 1,
	Heading		= 2,
	Code		= 3,
	List		= 4,
	Ruler		= 5,
	Quote		= 6,
}

local CombinedBlocks = {
	[BlockType.None]		= true,
	[BlockType.Paragraph]	= true,
	[BlockType.Code]		= true,
	[BlockType.List]		= true,
	[BlockType.Quote]		= true,
}

local function cleanup(s)
	return s:gsub("\t", "    ")
end

local function getTextWithIndentation(line)
	local indent, text = line:match("^%s*()(.*)")
	return text, math.floor(indent / 2)
end

-- Iterator: Iterates the string line-by-line
local function lines(s)
	return (s .. "\n"):gmatch("(.-)\n")
end

-- Iterator: Categorize each line and allows iteration
local function blockLines(md)
	local blockType = BlockType.None
	local nextLine = lines(md)
	local function it()
		local line = nextLine()
		if not line then
			return
		end
		-- Code
		if blockType == BlockType.Code then
			if line:match("^```") then
				blockType = BlockType.None
			end
			return BlockType.Code, line
		end
		-- Blank line
		if line:match("^%s*$") then
			return BlockType.None, ""
		end
		-- Ruler
		if line:match("^%-%-%-+") or line:match("^===+") then
			return BlockType.Ruler, ""
		end
		-- Heading
		if line:match("^#") then
			return BlockType.Heading, line
		end
		-- Code
		if line:match("^%s*```") then
			blockType = BlockType.Code
			return blockType, line
		end
		-- Quote
		if line:match("^%s*>") then
			return BlockType.Quote, line
		end
		-- List
		if line:match("^%s*%-%s+") or line:match("^%s*%*%s+") or line:match("^%s*[%u%d]+%.%s+") or line:match("^%s*%+%s+") then
			return BlockType.List, line
		end
		-- Paragraph
		return BlockType.Paragraph, line -- should take into account indentation of first-line
	end
	return it
end

-- Iterator: Joins lines of the same type into a single element
local function textBlocks(md)
	local it = blockLines(md)
	local lastBlockType, lastLine = it()
	return function ()
		-- This function works by performing a lookahead at the next line and then deciding what to do with the
		-- previous line based on that.
		local nextBlockType, nextLine = it()
		if nextBlockType == BlockType.Ruler and lastBlockType == BlockType.Paragraph then
			-- Combine paragraphs followed by rulers into headers
			local text = lastLine
			lastBlockType, lastLine = it()
			return BlockType.Heading, ("#"):rep(lastLine:sub(1, 1) == "=" and 2 or 1) .. " " .. text
		end
		local lines = { lastLine }
		while CombinedBlocks[nextBlockType] and nextBlockType == lastBlockType do
			table.insert(lines, nextLine)
			nextBlockType, nextLine = it()
		end
		local blockType, blockText = lastBlockType, table.concat(lines, "\n")
		lastBlockType, lastLine = nextBlockType, nextLine
		return blockType, blockText
	end
end

-- Iterator: Transforms raw blocks into sections with data
local function blocks(md, markup)
	local nextTextBlock = textBlocks(md)
	local function it()
		local blockType, blockText = nextTextBlock()
		if blockType == BlockType.None then
			return it() -- skip this block type
		end
		local block = {}
		if blockType then
			local text, indent = getTextWithIndentation(blockText)
			block.Indent = indent
			if blockType == BlockType.Paragraph then
				block.Text = markup(text)
			elseif blockType == BlockType.Heading then
				local level, text = blockText:match("^#+()%s*(.*)")
				block.Level, block.Text = level - 1, markup(text)
			elseif blockType == BlockType.Code then
				local syntax, code = text:match("^```(.-)\n(.*)\n```$")
				block.Syntax, block.Code = syntax, syntax == "raw" and code or sanitize(code)
			elseif blockType == BlockType.List then
				local lines = blockText:split("\n")
				for i, line in ipairs(lines) do
					local text, indent = getTextWithIndentation(line)
					local symbol, text = text:match("^(.-)%s+(.*)")
					lines[i] = {
						Level = indent,
						Text = markup(text),
						Symbol = symbol,
					}
				end
				block.Lines = lines
			elseif blockType == BlockType.Quote then
				local lines = blockText:split("\n")
				for i = 1, #lines do
					lines[i] = lines[i]:match("^%s*>%s*(.*)")
				end
				local rawText = table.concat(lines, "\n")
				block.RawText, block.Iterator = rawText, blocks(rawText, markup)
			end
		end
		return blockType, block
	end
	return it		
end

local function parseDocument(md, inlineParser)
	return blocks(cleanup(md), inlineParser or richText)
end

------------------------------------------------------------------------------------------------------------------------
-- Exports
------------------------------------------------------------------------------------------------------------------------

Markdown.sanitize = sanitize
Markdown.parse = parseDocument
Markdown.parseText = parseText
Markdown.parseTokens = parseModifierTokens
Markdown.BlockType = BlockType
Markdown.InlineType = InlineType
Markdown.ModifierType = ModifierType

return Markdown

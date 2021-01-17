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

local ModifierType = {
	None	= 0,
	Bold	= 1,
	Italic	= 2,
	Strike	= 3,
	Code	= 4,
	Ref		= 5,
}

local ModifierLookup = {
	["*"] = ModifierType.Bold,
	["_"] = ModifierType.Italic,
	["~"] = ModifierType.Strike,
	["`"] = ModifierType.Code,
}

local ModifierTags = {
	[ModifierType.Bold] = {"<b>", "</b>"},
	[ModifierType.Italic] = {"<i>", "</i>"},
	[ModifierType.Strike] = {"<s>", "</s>"},
	[ModifierType.Code] = {"<font face=\"RobotoCode\">", "</font>"},
}

local function characters(s)
	return s:gmatch(".")
end

local function last(t)
	return t[#t]
end

local function parseText(md)
	-- Asterisks are always passed as bold and underscores as italics.
	local stack = {}
	local s = ""
	for c in characters(md) do
		local modifierType = ModifierLookup[c]
		if modifierType then
			if last(stack) == modifierType then
				s = s .. ModifierTags[modifierType][2]
				table.remove(stack)
			else
				table.insert(stack, modifierType)
				s = s .. ModifierTags[modifierType][1]
			end
		else
			s = s .. c
		end
	end
	return s
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

local function clean(md)
	return md:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("\"", "&quot;"):gsub("'", "&apos;")
end

local function convertTabsToSpaces(s)
	return s:gsub("\t", "    ")
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
		if line:match("^\-\-\-+") or line:match("^===+") then
			return BlockType.Ruler, ""
		end
		-- Heading
		if line:match("^#") then
			return BlockType.Heading, line
		end
		-- Code
		if line:match("^```") then
			blockType = BlockType.Code
			return blockType, line
		end
		-- Quote
		if line:match("^>%s") then
			return BlockType.Quote, line
		end
		-- List
		if line:match("^\-%s+") or line:match("^\*%s+") or line:match("^%d*\.%s+") then
			return BlockType.List, line
		end
		-- Paragraph
		return BlockType.Paragraph, line -- should take into account indentation of first-line
	end
	return it
end

-- Iterator: Joins lines of the same type into a single element
local function blocks(md)
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
local function sections(md, useRichText)
	local nextBlock = blocks(md)
	local function it()
		local blockType, blockText = nextBlock()
		if blockType == BlockType.None then
			return it() -- skip this block type
		end
		local block = {}
		if blockType then
			local indent, text = blockText:match("^%s*()(.*)") -- TODO: This doesn't support tabs 
			if not indent then
				indent, text = 0, blockText
			end
			block.Indent = math.floor(indent / 2)
			if blockType == BlockType.Paragraph then
				block.Text = parseText(text)
			elseif blockType == BlockType.Heading then
				local level, text = blockText:match("^#+()%s*(.*)")
				block.Level, block.Text = level - 1, text
			elseif blockType == BlockType.Code then
				local syntax, code = text:match("^```(.-)\n(.*)\n```$")
				block.Syntax, block.Code = syntax, syntax == "raw" and code or clean(code)
			elseif blockType == BlockType.List then
				local lines = text:split("\n")
				for _, line in ipairs(lines) do
					parseText(line)
				end
				block.Lines = lines
			elseif blockType == BlockType.Quote then
				block.RawText, block.Iterator = text, sections(text, useRichText)
			end
		end
		return blockType, block
	end
	return it		
end

local function parseDocument(md)
	return sections(convertTabsToSpaces(md), true)
end

------------------------------------------------------------------------------------------------------------------------
-- Exports
------------------------------------------------------------------------------------------------------------------------

Markdown.sanitize = clean
Markdown.parse = parseDocument
Markdown.parseText = parseText
Markdown.BlockType = BlockType

return Markdown

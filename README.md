# Romarkable
Fast and lightweight markdown parser designed for Roblox and other Lua applications where HTML may not be applicable.

## Documentation
### Enum Markdown.BlockType

```
None
Paragraph
Heading
Code
List
Ruler
Quote
```

### iterator Markdown.parse(string document)
Returns an iterator which can be used to render. Each iteration returns the type of block and the information associated with it.

### Block Types

#### None
Never returned by the iterator

#### Paragraph
```
{
  int: Indent
  string: Text
}
```

#### Heading
```
{
  int: Indent
  int: Level
  string: Text
}
```

#### Code
```
{
  int: Indent
  string: Syntax
  string: Code
}
```

#### List
```
{
  int: Indent
  list<string>: Lines
}
```

#### Ruler
```
{
  int: Indent
}
```

#### Quote
```
{
  int: Indent
  iterator: Iterator (Allows the quote to be iterated and rendered)
  string: RawText
}
```

### Usage
```lua
for blockType, block in Markdown.parse(md) do
  -- do something
end
```

### string Markdown.parseText(string inlineText)
Takes a string of inline markdown elements and converts them to markup which can be used in Roblox's rich text engine and HTML.

```lua
local text = Markdown.parseText("*Bold* _Italics_ ~Strike~ `Code`")
print(text) --> <b>Bold</b> <i>Italics</i> <s>Strike</s> <font face="RobotoCode">Code</font>
```

### string Markdown.sanitize(string text)
Converts a string which may contain richtext to a plaintext string.

```lua
local text = clean("<b>Text</b>")
print(text) --> &lt;b&gt;Text&lt;/b&gt;
```

## Known Issues

- Lines do not include indentation information (other than for the first line). Would be useful if they did...
- References are not supported

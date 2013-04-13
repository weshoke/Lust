Lust
====

Lua String Templates

Overview
---
Lust is a templating system for Lua loosely based on Terrence Parr's [StringTemplate](http://www.stringtemplate.org/).  Lust has been designed to enable the simple expression of complex string synthesis problems.  It is particularly well suited for generating strings from hierarchical data structures.  Lust itself encompases a language for writing templates and an interpreter for applying the templates to a datastructure.

### Lust features
* scoped templates
* dynamic template dispatch based on runtime information
* iteration through map and numeric loop mechanisms
* conditional template application
* whitespace indentation preservation
* insertion of separator tokens between strings generated via iteration


### Authors
Lust is developed by Wesley Smith and Graham Wakefield with the support of Cycling '74.

### License
Lust is licensed under the standard [MIT license](http://www.lua.org/license.html) just like the Lua Language.

### Dependencies
Lust depends on the [Lua Parsing Expression Grammar (LPEG)](http://www.inf.puc-rio.br/~roberto/lpeg/) module.


High-Level Overview
---
In Lust, you author a set of templates, giving each one a name.  Templates can be grouped together by putting them in a common namespace.  To use the templates for string synthesis, a datastructure is passed to the Lust object, which initiates the synthesis process by applying the root template rule to the datastructure.  As the root rule invokes subtemplates, Lust walks the datastructure passed in by following the commands described by operators embedded in the templates.  Lust walks a datastructure either by iterating over arrays of values or by looking at named fields.


Lust Basics
---
The most fundamental structures in Lust are *templates* and *environments*.  Templates are named strings, and environments represent the set of values a template has access to.  The environment of a template is just like the concept of scope in a programming language.  It provides a set of named values that can be referenced and operated on.

### Stringification ###
Stringification takes a value and renders it directly into a string.  In Lust, the stringification operator is indicated by the $ symbol.  

```lua
-- $. applies the current environment:
Lust([[$.]]):gen("hello") -- res: "hello"
```

```lua
-- $1 selects item from environment-as-array:
Lust([[$1 $2]]):gen{ "hello", "world" } -- res: "hello world"
```

```lua
-- $foo selects item from environment-as-dictionary:
Lust[[$foo $bar]]:gen{ foo="hello", bar="world" } -- res: "hello world"
```

```lua
-- $< > can be used to avoid ambiguity:
Lust[[$<1>2 $<foo>bar]]:gen{ "hello", foo="world" } -- res: "hello2 worldbar"
```

```lua
-- selections can be constructed as paths into the environment:
Lust[[$a.b.c $1.1.1]]:gen{ a={ b={ c="hello" } }, { { "world" } } } -- res: "hello world"
Lust[[$a.1 $1.b]]:gen{ a={ "hello" }, { b="world" } } -- res: "hello world"
```

```lua
-- the # symbol prints the length of an environment selection:
Lust[[$#.]]:gen{ 1, 2, 3 } -- res: "3"
Lust:[[$#foo.bar]]:gen{ foo={ bar={ 1, 2, 3 } } } -- res: "3"
```

```lua
-- selections can be resolved dynamically using (x):
Lust[[$(x)]]:gen{ x="foo", foo="hello" } -- res: "hello"
Lust[[$(x.y).1]]:gen{ x={ y="foo" }, foo={"hello"} } -- res: "hello"
```


### Template Application ###
Template application applies a template to a particular environment.  The template invocation operator is indicated by the @ symbol.

```lua
-- the @name invokes a statically named sub-template:
local temp = Lust[[@child]]
-- define a subtemplate:
temp.child = "$1 to child"
temp:gen{"hello"} -- res: "hello to child"
```

```lua
-- subtemplates can also be specified in the constructor-table:
Lust{
	[[@child]],
	child = "$1 to child",
}:gen{"hello"}	-- res: "hello to child"
```

```lua
-- subtemplate invocations can use < > to avoid ambiguity:
Lust{
	[[@<child>hood]],
	child = "$1 to child",
}:gen{"hello"} -- res: "hello to childhood"
```

```lua
-- subtemplates with subtemplates:
Lust{
	[[@child, @child.grandchild]],
	child = {
		"$1 to child",
		grandchild = "$1 to grandchild",
	},
}:gen{"hello"} -- res: "hello to child, hello to grandchild"
```

```lua
-- subtemplates with subtemplates (alternative naming):
Lust{
	[[@child, @child.grandchild]],
	child = "$1 to child",
	["child.grandchild"] = "$1 to grandchild",
}:gen{"hello"} -- res: "hello to child, hello to grandchild"
```

```lua
-- subtemplate names can also be resolved dynamically, according to model values, using (x):
Lust{
	[[@(x), @(y)]],
	child1 = "hello world",
	child2 = "hi"
}:gen{ x="child1", y="child2" } -- res: "hello world, hi"
```

```lua
-- the environment passed to a subtemplate can be specifed as a child of the current environment:
Lust{
	[[@1:child @two:child]],
	child = [[$. child]],
}:{ "one", two="two" } -- res: "one child two child"
```

```lua
-- the symbol . can be used to explicitly refer to the current environment:
Lust{
	[[@child == @.:child]],
	child = [[$1 child]],
}:gen{ "hello" } -- res: "hello child == hello child"
```

```lua
-- subtemplate paths can mix static and dynamic terms:
Lust{[[@child.(x), @(y).grandchild, @(a.b)]], 
	child "$1 to child",
	["child.grandchild"] = "$1 to grandchild",
}:gen{ 
	x="grandchild", 
	y="child", 
	"hello", 
	a = { b="child" } 
} -- res: "hello to grandchild, hello to grandchild, hello to child"
```

```lua
-- child environments can be specified using multi-part paths:
Lust{
	[[@a.1.foo:child]],
	child = [[$. child]],
}:gen{ a={ { foo="hello" } } } -- res: "hello child"
```

```lua
-- subtemplates can be specified inline using @{{ }}:
Lust([[@foo.bar:{{$1 $2}}]]):gen{ foo={ bar={ "hello", "world" } } } -- res: "hello world"
```

```lua
-- environments can also be specified dynamically
-- the @{ } construction is similar to Lua table construction
Lust([[@{ ., greeting="hello" }:{{$greeting $1.place}}]]):gen{ place="world" } -- res: "hello world"
Lust([[@{ "hello", a.b.place }:{{$1 $2}}]]):gen{ a = { b = { place="world" } } } -- res: "hello world"
Lust([[@{ 1, place=a.b }:{{$1 $place.1}}]]):gen{ "hello", a = { b = { "world" } } } -- res: "hello world"
```

```lua
-- dynamic environments can contain arrays:
Lust([[@{ args=["hello", a.b] }:{{$args.1 $args.2.1}}]]):gen{ a = { b = { "world" } } } -- res: "hello world"
```

```lua
-- dynamic environments can contain subtemplate applications:
Lust{
	[[@{ .:child, a=x:child.grandchild }:{{$1, $a}}]],
	child = "$1 to child",
	["child.grandchild"] = "$1 to grandchild",
}:gen{ "hi", x = { "hello" } } -- res: "hi to child, hello to grandchild"
```

```lua
-- dynamic environments can be nested:
Lust{
	[[@{ { "hello" }, foo={ bar="world" } }:sub]],
	sub = [[$1.1 $foo.bar]],
}:gen{} -- res: "hello world"
```

## Conditions
The @if condition takes a boolean expression and applies a template or value if it evaluates to true.  If there is a corresponding else template/value, then it will be applied if the expression evaluates to false

```lua
-- conditional templates have a conditional test followed by a template application
-- @if(x) tests for the existence of x in the model
local temp = Lust{
	[[@if(x)<greet>]],
	greet = "hello",
}
temp:gen{ x=1 } 	-- res: "hello"
temp:gen{ } 		-- res: ""
```

```lua
-- @if(?(x)) evaluates x in the model, and then checks if the result is a valid template name
-- this example also demonstrates using dynamically evalutated template application:
local temp = Lust{
	[[@if(?(op))<(op)>]],
	child = "I am a child",
}
temp:gen{ op="child" } -- res: "I am a child"
```

```lua
-- using else and inline templates:
local temp = Lust[[@if(x)<{{hello}}>else<{{bye bye}}>]]
temp:gen{ x=1 }	-- res: "hello"
temp:gen{  }	-- res: "bye bye"
```

```lua
-- @if(#x > n) tests that the number of items in the model term 'x' is greater than n:
local temp = Lust[[@if(#. > "0")<{{at least one}}>]]
temp:gen{ "a" }	-- res: "at least one")
temp:gen{  } 	-- res: ""
```

```lua
-- compound conditions:
local temp = Lust[[@if(#x > "0" and #x < "5")<{{success}}>]]
temp:gen{ x={ "a", "b", "c", "d" } }		-- res: "success"
temp:gen{ x={ "a", "b", "c", "d", "e" } }	-- res: ""
temp:gen{ x={  } }							-- res: ""
temp:gen{ }									-- res: ""
```

```lua
-- compound conditions:
local temp = Lust[[@if(x or not not not y)<{{success}}>else<{{fail}}>]]
temp:gen{ x=1 }			-- res: "success"
temp:gen{ x=1, y=1 }	-- res: "success"
temp:gen{ y=1 }			-- res: "fail"
temp:gen{ }				-- res: "success"
```

```lua
-- compound conditions:
local temp = Lust[[@if(n*"2"+"1" > #x)<{{success}}>else<{{fail}}>]]
temp:gen{ n=3, x = { "a", "b", "c" } }	-- res: "success"
temp:gen{ n=1, x = { "a", "b", "c" } }	-- res: "fail"
```


### Iteration

Lust has two main methods for creating iteration statements: a map function and numeric iteration.  For the @map function, there are a variety of ways that it can be called depdening on the situation

```lua
-- @map can iterate over arrays in the environment:
local temp = Lust[[@map{ n=numbers }:{{$n.name }}]]
temp:gen{
	numbers = {
		{ name="one" },
		{ name="two" },
		{ name="three" },
	}
}
-- result: "one two three "
```

```lua
-- assigning mapped values a name in the environment
local temp = Lust[[@map{ n=numbers }:{{$n }}]]
temp:gen{
	numbers = { "one", "two", "three" }
}
-- result: "one two three "
```

```lua
-- the _separator field can be used to insert elements between items:
local temp = Lust[[@map{ n=numbers, _separator=", " }:{{$n.name}}]]
temp:gen{
	numbers = {
		{ name="one" },
		{ name="two" },
		{ name="three" },
	}
}
-- result: "one, two, three"
```

```lua
-- _ can be used as a shorthand for _separator:
local temp = Lust[[@map{ n=numbers, _=", " }:{{$n.name}}]]
temp:gen{
	numbers = {
		{ name="one" },
		{ name="two" },
		{ name="three" },
	}
}
-- result: "one, two, three"
```

```lua
-- a map can iterate over multiple arrays in parallel
local temp = Lust[[@map{ a=letters, n=numbers, _=", " }:{{$a $n.name}}]]
temp:gen{
	numbers = {
		{ name="one" },
		{ name="two" },
		{ name="three" },
	},
	letters = {
		"a", "b", "c",
	}
}
-- res: "a one, b two, c three"
```

```lua
-- if parallel mapped items have different lengths, the longest is used:
local temp = Lust[[@map{ a=letters, n=numbers, _=", " }:{{$a $n.name}}]]
temp:gen{
	numbers = {
		{ name="one" },
		{ name="two" },
		{ name="three" },
	},
	letters = {
		"a", "b", "c", "d",
	}
}
-- res: "a one, b two, c three, d "
```

```lua
-- if parallel mapped items are not arrays, they are repeated each time:
local temp = Lust[[@map{ a=letters, n=numbers, prefix="hello", count=#letters, _=", " }:{{$prefix $a $n.name of $count}}]]
temp:gen{
	numbers = {
		{ name="one" },
		{ name="two" },
		{ name="three" },
	},
	letters = {
		"a", "b", "c", "d",
	}
}
-- res: "hello a one of 4, hello b two of 4, hello c three of 4, hello d  of 4"
```

```lua
-- the 'i1' and 'i0' fields are added automatically for one- and zero-based array indices:
local temp = Lust[[@map{ n=numbers }:{{$i0-$i1 $n.name }}]]
temp:gen{
	numbers = {
		{ name="one" },
		{ name="two" },
		{ name="three" },
	}
}
-- res: "0-1 one 1-2 two 2-3 three "
```

```lua
-- if the map only contains an un-named array, each item of the array becomes the environment applied in each iteration:
local temp = Lust[["@map{ ., _separator='", "' }:{{$name}}"]]
temp:gen{
	{ name="one" },
	{ name="two" },
	{ name="three" },
}
-- res: '"one", "two", "three"'

local temp = Lust[[@map{ numbers, count=#numbers, _separator=", " }:{{$name of $count}}]]
temp:gen{
	numbers = {
		{ name="one" },
		{ name="two" },
		{ name="three" },
	}
}
-- res: "one of 3, two of 3, three of 3"
```

```lua
-- @rest is like @map, but starts from the 2nd item:
local temp = Lust[[@rest{ a=letters, n=numbers, _separator=", " }:{{$a $n.name}}]]
temp:gen{
	numbers = {
		{ name="one" },
		{ name="two" },
		{ name="three" },
	},
	letters = {
		"a", "b", "c",
	}
}
-- res: "b two, c three"
```

```lua
-- @iter can be used for an explicit number of repetitions:
local temp = Lust[[@iter{ "3" }:{{repeat $i1 }}]]
temp:gen{} -- res: "repeat 1 repeat 2 repeat 3 "
```

```lua
-- again, _separator works:
local temp = Lust[[@iter{ "3", _separator=", " }:{{repeat $i1}}]]
temp:gen{} -- res: "repeat 1, repeat 2, repeat 3"
```

```lua
-- @iter can take an array item; it will use the length of that item:
local temp = Lust[[@iter{ numbers, _separator=", " }:{{repeat $i1}}]]
temp:gen{
	numbers = {
		{ name="one" },
		{ name="two" },
		{ name="three" },
	}
}
-- res: "repeat 1, repeat 2, repeat 3"

```

```lua
-- @iter can take a range for start and end values:
Lust([[@iter{ ["2", "3"] }:{{repeat $i1 }}]]):gen{}
-- res: "repeat 2 repeat 3 "
```

```lua
local temp = Lust[[@iter{ ["2", numbers], _separator=", " }:{{repeat $i1}}]]
temp:gen{
	numbers = {
		{ name="one" },
		{ name="two" },
		{ name="three" },
	}
}
-- res: "repeat 2, repeat 3"
```

### Indentation
If template application is preceded by only whitespace on a given line, every line the template generates will be indented to the same level as the template application.

```lua
-- helper function to un-escape \n and \t in Lua's long string
local function nl(str) return string.gsub(str, [[\n]], "\n"):gsub([[\t]], "\t") end

-- if a template application occurs after whitespace indentation, 
-- any generated newlines will repeat this indentation:
local temp = Lust{nl[[
	@iter{ "3", _separator="\n" }:child]],
	child = [[line $i1]],
}
--[=[ res: [[
	line 1
	line 2
	line 3]]
--]=]
```


### Handler Registration
For special cases, handlers can be associated with a template for runtime modification of the template's environment.

```lua
-- a handler can be registered for a named template
-- the handler allows a run-time modification of the environment:
local temp = Lust{
	[[@child]],
	child = [[$1]],
}
local model = { "foo" }
local function double_env(env)
	-- create a new env:
	local ee = env[1] .. env[1]
	return { ee }
end
temp:register("child", double_env)
-- res: "foofoo"
```
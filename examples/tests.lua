local Lust = require"Lust"

--------------------------------------------------------------------------------------------------
-- substitutions:
--------------------------------------------------------------------------------------------------

local function test(patt, model, result)
	local temp = Lust(patt)
	local ok, str = pcall(temp.gen, temp, model)
	if not ok then
		pcall(temp.dump, temp)
		error(str)
	elseif (str ~= result) then
		temp:ast_dump()
		temp:dump()
		print(str)
		error("test failed", 2)
	end
end

-- $. applies the current environment:
test([[$.]], "hello", "hello")

-- $1 selects item from environment-as-array:
test([[$1 $2]], { "hello", "world" }, "hello world")

-- $foo selects item from environment-as-dictionary:
test([[$foo $bar]], { foo="hello", bar="world" }, "hello world")

-- $< > can be used to avoid ambiguity:
test([[$<1>2 $<foo>bar]], { "hello", foo="world" }, "hello2 worldbar")

-- selections can be constructed as paths into the environment:
test([[$a.b.c $1.1.1]], { a={ b={ c="hello" } }, { { "world" } } }, "hello world")
test([[$a.1 $1.b]], { a={ "hello" }, { b="world" } }, "hello world")

-- the # symbol prints the length of an environment selection:
test([[$#.]], { 1, 2, 3 }, "3")
test([[$#foo.bar]], { foo={ bar={ 1, 2, 3 } } }, "3")

-- selections can be resolved dynamically using (x):
test([[$(x)]], { x="foo", foo="hello" }, "hello")
test([[$(x.y).1]], { x={ y="foo" }, foo={"hello"} }, "hello")

--------------------------------------------------------------------------------------------------
-- sub-template applications:
--------------------------------------------------------------------------------------------------

-- the @name invokes a statically named sub-template:
local temp = Lust[[@child]]
-- define a subtemplate:
temp.child = "$1 to child"
assert(temp:gen{"hello"} == "hello to child")

-- subtemplates can also be specified in the constructor-table:
local temp = {
	[[@child]],
	child = {
		"$1 to child",
	},
}
test(temp, {"hello"}, "hello to child")

-- subtemplate invocations can use < > to avoid ambiguity:
local temp = {
	[[@<child>hood]],
	child = {
		"$1 to child",
	},
}
test(temp, {"hello"}, "hello to childhood")

-- subtemplates with subtemplates:
local temp = {
	[[@child, @child.grandchild]],
	child = {
		"$1 to child",
		grandchild = "$1 to grandchild",
	},
}
test(temp, {"hello"}, "hello to child, hello to grandchild")

local temp = {
	[[@child, @child.grandchild]],
	child = "$1 to child",
	["child.grandchild"] = "$1 to grandchild",
}
test(temp, {"hello"}, "hello to child, hello to grandchild")

-- subtemplate names can also be resolved dynamically, according to model values, using (x):
local temp = {
	[[@(x), @(y)]],
	child1 = { "hello world", },
	child2 = { "hi" },
}
test(temp, { x="child1", y="child2" }, "hello world, hi")

-- subtemplate paths can mix static and dynamic terms:
local temp = {
	[[@child.(x), @(y).grandchild, @(a.b)]], 
	child = {
		"$1 to child",
		grandchild = "$1 to grandchild",
	},
}
local model = { 
	x="grandchild", 
	y="child", 
	"hello", 
	a = { b="child" } 
}
test(temp, model, "hello to grandchild, hello to grandchild, hello to child" )

-- the environment passed to a subtemplate can be specifed as a child of the current environment:
local temp = {
	[[@1:child @two:child]],
	child = [[$. child]],
}
test(temp, { "one", two="two" }, "one child two child")

-- the symbol . can be used to explicitly refer to the current environment:
local temp = {
	[[@child == @.:child]],
	child = [[$1 child]],
}
test(temp, { "hello" }, "hello child == hello child")

-- child environments can be specified using multi-part paths:
local temp = {
	[[@a.1.foo:child]],
	child = [[$. child]],
}
test(temp, { a={ { foo="hello" } } }, "hello child")

local temp = {
	[[@a.1.foo:child, @a.1.foo:child.grandchild]],
	child = {
		"$. to child",
		grandchild = "$. to grandchild",
	},
}
test(temp, { a={ { foo="hello" } } }, "hello to child, hello to grandchild")

local temp = {
	[[@a.1.foo:child, @a.1.foo:child.grandchild, @a.1.foo:(x.y)]],
	child = {
		"$. to child",
		grandchild = "$. to grandchild",
	},
}
local model = { a={ { foo="hello" } }, x={ y="child" } }
test(temp, model, "hello to child, hello to grandchild, hello to child")

-- subtemplates can be specified inline using @{{ }}:
test([[@{{$1 $2}}]], { "hello", "world" }, "hello world")
-- this is more useful for dynamic environments etc:
test([[@foo.bar:{{$1 $2}}]], { foo={ bar={ "hello", "world" } } }, "hello world")

-- environments can also be specified dynamically
-- the @{ } construction is similar to Lua table construction
local temp = [[@{ ., greeting="hello" }:{{$greeting $1.place}}]]
test(temp, { place="world" }, "hello world")

local temp = [[@{ "hello", a.b.place }:{{$1 $2}}]]
test(temp, { a = { b = { place="world" } } }, "hello world")

local temp = [[@{ 1, place=a.b }:{{$1 $place.1}}]]
test(temp, { "hello", a = { b = { "world" } } }, "hello world")

-- dynamic environments can contain arrays:
local temp = [[@{ args=["hello", a.b] }:{{$args.1 $args.2.1}}]]
test(temp, { a = { b = { "world" } } }, "hello world")

-- dynamic environments can contain subtemplate applications:
local temp = {
	[[@{ .:child, a=x:child.grandchild }:{{$1, $a}}]],
	child = {
		"$1 to child",
		grandchild = "$1 to grandchild",
	},
}
test(temp, { "hi", x = { "hello" } }, "hi to child, hello to grandchild")

-- dynamic environments can be nested:
local temp = {
	[[@{ { "hello" }, foo={ bar="world" } }:sub]],
	sub = [[$1.1 $foo.bar]],
}	
test(temp, {}, "hello world")

-- conditional templates have a conditional test followed by a template application
-- @if(x) tests for the existence of x in the model
local temp = {
	[[@if(x)<greet>]],
	greet = "hello",
}
test(temp, { x=1 }, "hello")
test(temp, {  }, "")

local temp = {
	[[@if(1)<greet>]],
	greet = "hello",
}
test(temp, { "something" },  "hello")
test(temp, {  },  "")

-- @if(?(x)) evaluates x in the model, and then checks if the result is a valid template name
-- this example also demonstrates using dynamically evalutated template application:
local temp = {
	[[@if(?(op))<(op)>]],
	child = "I am a child",
}
test(temp, { op="child" },  "I am a child")

-- using else and inline templates:
local temp = [[@if(x)<{{hello}}>else<{{bye bye}}>]]
test(temp, { x=1 }, "hello")
test(temp, {  }, "bye bye")

-- @if(#x > n) tests that the number of items in the model term 'x' is greater than n:
local temp = [[@if(#. > "0")<{{at least one}}>]]
test(temp, { "a", }, "at least one")
test(temp, {  }, "")

-- compound conditions:
local temp = [[@if(#x > "0" and #x < "5")<{{success}}>]]
test(temp, { x={ "a", "b", "c", "d" } }, "success")
test(temp, { x={ "a", "b", "c", "d", "e" } }, "")
test(temp, { x={  } }, "")
test(temp, { }, "")

local temp = [[@if(x or not not not y)<{{success}}>else<{{fail}}>]]
test(temp, { x=1 }, "success")
test(temp, { x=1, y=1 }, "success")
test(temp, { y=1 }, "fail")
test(temp, { }, "success")

local temp = [[@if(n*"2"+"1" > #x)<{{success}}>else<{{fail}}>]]
test(temp, { n=3, x = { "a", "b", "c" } }, "success")
test(temp, { n=1, x = { "a", "b", "c" } }, "fail")

-- @map can iterate over arrays in the environment:
local temp = [[@map{ n=numbers }:{{$n.name }}]]
local model = {
	numbers = {
		{ name="one" },
		{ name="two" },
		{ name="three" },
	}
}
test(temp, model, "one two three ")

local temp = [[@map{ n=numbers }:{{$n }}]]
local model = {
	numbers = { "one", "two", "three" }
}
test(temp, model, "one two three ")

-- the _separator field can be used to insert elements between items:
local temp = [[@map{ n=numbers, _separator=", " }:{{$n.name}}]]
local model = {
	numbers = {
		{ name="one" },
		{ name="two" },
		{ name="three" },
	}
}
test(temp, model, "one, two, three")

-- _ can be used as a shorthand for _separator:
local temp = [[@map{ n=numbers, _=", " }:{{$n.name}}]]
local model = {
	numbers = {
		{ name="one" },
		{ name="two" },
		{ name="three" },
	}
}
test(temp, model, "one, two, three")

-- a map can iterate over multiple arrays in parallel
local temp = [[@map{ a=letters, n=numbers, _=", " }:{{$a $n.name}}]]
local model = {
	numbers = {
		{ name="one" },
		{ name="two" },
		{ name="three" },
	},
	letters = {
		"a", "b", "c",
	}
}
test(temp, model, "a one, b two, c three")

-- if parallel mapped items have different lengths, the longest is used:
local temp = [[@map{ a=letters, n=numbers, _=", " }:{{$a $n.name}}]]
local model = {
	numbers = {
		{ name="one" },
		{ name="two" },
		{ name="three" },
	},
	letters = {
		"a", "b", "c", "d",
	}
}
test(temp, model, "a one, b two, c three, d ")

-- if parallel mapped items are not arrays, they are repeated each time:
local temp = [[@map{ a=letters, n=numbers, prefix="hello", count=#letters, _=", " }:{{$prefix $a $n.name of $count}}]]
local model = {
	numbers = {
		{ name="one" },
		{ name="two" },
		{ name="three" },
	},
	letters = {
		"a", "b", "c", "d",
	}
}
test(temp, model, "hello a one of 4, hello b two of 4, hello c three of 4, hello d  of 4")

-- the 'i1' and 'i0' fields are added automatically for one- and zero-based array indices:
local temp = [[@map{ n=numbers }:{{$i0-$i1 $n.name }}]]
local model = {
	numbers = {
		{ name="one" },
		{ name="two" },
		{ name="three" },
	}
}
test(temp, model, "0-1 one 1-2 two 2-3 three ")


-- if the map only contains an un-named array, each item of the array becomes the environment applied in each iteration:
local temp = [["@map{ ., _separator='", "' }:{{$name}}"]]
local model = {
	{ name="one" },
	{ name="two" },
	{ name="three" },
}
test(temp, model, '"one", "two", "three"')

local temp = [[@map{ numbers, count=#numbers, _separator=", " }:{{$name of $count}}]]
local model = {
	numbers = {
		{ name="one" },
		{ name="two" },
		{ name="three" },
	}
}
test(temp, model, "one of 3, two of 3, three of 3")

-- @rest is like @map, but starts from the 2nd item:
local temp = [[@rest{ a=letters, n=numbers, _separator=", " }:{{$a $n.name}}]]
local model = {
	numbers = {
		{ name="one" },
		{ name="two" },
		{ name="three" },
	},
	letters = {
		"a", "b", "c",
	}
}
test(temp, model, "b two, c three")

-- @iter can be used for an explicit number of repetitions:
local temp = [[@iter{ "3" }:{{repeat $i1 }}]]
test(temp, {}, "repeat 1 repeat 2 repeat 3 ")

-- again, _separator works:
local temp = [[@iter{ "3", _separator=", " }:{{repeat $i1}}]]
test(temp, {}, "repeat 1, repeat 2, repeat 3")

-- @iter can take an array item; it will use the length of that item:
local temp = [[@iter{ numbers, _separator=", " }:{{repeat $i1}}]]
local model = {
	numbers = {
		{ name="one" },
		{ name="two" },
		{ name="three" },
	}
}
test(temp, model, "repeat 1, repeat 2, repeat 3")

-- @iter can take a range for start and end values:
local temp = [[@iter{ ["2", "3"] }:{{repeat $i1 }}]]
test(temp, {}, "repeat 2 repeat 3 ")

local temp = [[@iter{ ["2", numbers], _separator=", " }:{{repeat $i1}}]]
test(temp, model, "repeat 2, repeat 3")

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
assert(temp:gen(model) == "foofoo")


---[===[

-- indentation:
-- if a template application occurs after whitespace indentation, 
-- any generated newlines will repeat this indentation:
local function nl(str) return string.gsub(str, [[\n]], "\n"):gsub([[\t]], "\t") end
local temp = {nl[[
	@iter{ "3", _separator="\n" }:child]],
	child = [[line $i1]],
}
test(temp, {}, [[
	line 1
	line 2
	line 3]])
	
local temp = {
	nl[[
	@iter{ "3", _="\n" }:row]],
	row = nl[[row $i1:
	@iter{ "2", _="\n"}:column]],
	column = [[col $i1]],
}
test(temp, {}, [[
	row 1:
		col 1
		col 2
	row 2:
		col 1
		col 2
	row 3:
		col 1
		col 2]])


--]===]
--[[ 

TODO:

test inheritence & loop nesting

Thoughts:

A template should be able invoke itself recursively?

This is a common pattern for defaults,
perhaps we can add a syntax to make it simpler?
@if(min)<{{$min}}>else<{{0}}>

Another common idiom, which could benefit from a shorthand:
@if(?x)<{{x}}>				=>  @x? or @?x
@if(?x)<{{x}}>else<foo>		=>  @x?foo or @?x/foo

This idiom was also common: @map{ v=. }:{{$v}}
but perhaps it could simply be @map{.}:{{$.}}  ??

What does $. mean when the current env is a table?
	(what does $1 mean when the current env is a string?)

What if we also allowed Lua functions as RHS of templates?

--]]


print("tests succeeded")
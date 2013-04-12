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
* conditional template invocation
* whitespace indentation preservation
* insertion of separator tokens between strings generated via iteration

```ruby
require 'redcarpet'
markdown = Redcarpet.new("Hello World!")
puts markdown.to_html
```


High-Level Overview
---
In Lust, you author a set of templates, giving each one a name.  Templates can be grouped together by putting them in a common namespace.  To use the templates for string synthesis, a datastructure is passed to the Lust object, which initiates the synthesis process by applying the root template rule to the datastructure.  As the root rule invokes subtemplates, Lust walks the datastructure passed in by following the commands described by operators embedded in the templates.  Lust walks a datastructure either by iterating over arrays of values or by looking at named fields.


Lust Basics
---
The most fundamental structures in Lust are *templates* and *environments*.  Templates are named strings, and environments represent the set of values a template has access to.  The environment of a template is just like the concept of scope in a programming language.  It provides a set of named values that can be referenced and operated on.

### Stringification ###
Stringification takes a value and renders it directly into a string.  In Lust, the stringification operator is indicated by the $ symbol.  For example,
	
```
$name is my name!
```

will look in the current environment for the value "name" and replace the characters "$name" with the value rendered as a string, which basically boils down to calling tostring() on the value if it exists.  If the value is nil, "$name" will be replaced with the empty string.

Values further down the hierarchy of the current environment can be access using the '.' operator just like with Lua tables.  Given a datastructure

```
{ field={ subfield="Hi" }, another="thing" }
```

the template

```
$field.subfield there!
```

will render "Hi there!" with the datastructure as its environment.

In some cases, however, it may be desirable to render a '.' character after the stringification operator, but since the syntax uses '.' to lookup subfields, this isn't possible without delimiting the range of characters Lust should interpret for a particular operation.  Operators can be explicitly delimited by with the '<' and '>' characters.  Using the datastructure above, the template 

```
$<another>.process
```

will be rendered as "thing.process" because the stringification operator is wrapped in delimiting characters, so the '.' chartacter is not counted as part of the definition and is instead rendered as plain text.


### Template Application ###
Template application applies a template to a particular environment.  The template invocation operator is indicated by the @ symbol.  In the simple case of applying a template to the current environment, template application looks like

```
@thetemplate
```

which would apply the templated named "thetemplate" to the current environment.  While useful, the more typical case is to apply a template to a value in the current environment.  This looks like:

```
@field:thetemplate
```

The difference from the previous example is that there is now a value name followed by a ':' before the template name where ':' apply what preceded to what follows.  As with stringification, it's possible to index down the hierarchy of the environment using the '.' operator.  For example:

```
@field.subfield:thetemplate
```

### Template Namespacing  ###
When a template is added to a Lust object, it's given a name.  As when indexing into the environment, namespaces of templates can be setup using the '.' operator.

```
Lust{
	[1] = "@growl -> @howl",
	gowl = "grrrrr @exclaim",
	["growl.exclaim"] = "^^^^^",
	howl = "ooowww @exclaim",
	["howl.exclaim"] = "~~~~~~",
}
```

In this code, there are five templates defined with two template namespaces that each have a subtemplate.  The two namespaces are "growl" and "howl".  Notice that in both the growl and howl template the template application operator calls the "exclaim" template and there are two possible templates that could be references.  With template namespaces and the template application operator, Lust looks for the most specific template first and if not found contiues looking for a more general template until one is found or there are no more template names to look for and an error is generated.  As a result, the "@exclaim" in the template "growl" will cause Lust to first look for the template name "growl.exclaim" and if it doesn't exist it will then look for the template "exclaim".  Since "growl.exclaim" does exist, it will be used.  This logic applies equally to the case of "@exclaim" in the "howl" template".  Rendering out with the templates above will generate the result

	grrrrr ^^^^^ -> ooowww ~~~~~~
	
If we redined the "growl" template to be "grrrrr @howl.exclaim" instead, the result would be

	grrrrr ~~~~~~ -> ooowww ~~~~~~

instead because Lust first looks for "growl.howl.exclaim", which it doesn't find, and then "howl.exclaim", which does exist and gets used.


### Dynamic dispatch
Dynamic dispatch is one of the most powerful features of Lust because it enables stringification and template application operations to be defined in terms of runtime information in the current environment instead of statically when the template is written.  Careful use of dynamic dispatch can dramatically simplify complex template interdependencies.

Dynamic dispatch is indicated with the '(' and ')' symbols and can be used for any part of a template or environment variable name.  The name within the '(' and ')' characters is looked up in the environment and used to construct a stringification or template application operator.  For example

```
$(name) is my $field.(subname)
```

with datastructure 

```
{
	name = "alfred",
	subname = "bonkers",
	alfred = "hommie",
	field = { bonkers="love" }
}
```

containts two stringification operators, each with dynamic dispatch.  In the first case, "$(name)" will lookup the "name" value in the environment and use the value to lookup another value.  The second case of "$field.(subname)" will look up the value of "subname" in the environment and concatenate it with "field" to look up a nested value.  Applying the template to the above datastructure gives:

	hommie is my love
	
Other examples of dynamic dispatch include:

```
$name.(another.name)
@(template)
@vals:(template)
```


### Inline templates
Sometimes template definitions are short or one-off definitions that aren't significant enough to warrent writing as a separate named template.  Inline templates can be defined anywhere a template name would be used and are delimited by the '{{' and ''}}' symbols.

```
@{{Hi $name}}
@person:{{Hi $name}}
```



### Iteration

Lust has two main methods for creating iteration statements: a map function and numeric iteration.  For the map function, there are a variety of ways that it can be called depdening on the situation

```
-- @map can iterate over arrays in the environment:
local temp = [[@map{ n=numbers }:{{$n.name }}]]
local model = {
	numbers = {
		{ name="one" },
		{ name="two" },
		{ name="three" },
	}
}
-- result: "one two three "

-- assigning mapped values a name in the environment
local temp = [[@map{ n=numbers }:{{$n }}]]
local model = {
	numbers = { "one", "two", "three" }
}
-- result: "one two three "

-- the _separator field can be used to insert elements between items:
local temp = [[@map{ n=numbers, _separator=", " }:{{$n.name}}]]
local model = {
	numbers = {
		{ name="one" },
		{ name="two" },
		{ name="three" },
	}
}
-- result: "one, two, three"

-- _ can be used as a shorthand for _separator:
local temp = [[@map{ n=numbers, _=", " }:{{$n.name}}]]
local model = {
	numbers = {
		{ name="one" },
		{ name="two" },
		{ name="three" },
	}
}
-- result: "one, two, three"

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
-- res: "a one, b two, c three"

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
-- res: "a one, b two, c three, d "

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
-- res: "hello a one of 4, hello b two of 4, hello c three of 4, hello d  of 4"

-- the 'i1' and 'i0' fields are added automatically for one- and zero-based array indices:
local temp = [[@map{ n=numbers }:{{$i0-$i1 $n.name }}]]
local model = {
	numbers = {
		{ name="one" },
		{ name="two" },
		{ name="three" },
	}
}
-- res: "0-1 one 1-2 two 2-3 three "


-- if the map only contains an un-named array, each item of the array becomes the environment applied in each iteration:
local temp = [["@map{ ., _separator='", "' }:{{$name}}"]]
local model = {
	{ name="one" },
	{ name="two" },
	{ name="three" },
}
-- res: '"one", "two", "three"'

local temp = [[@map{ numbers, count=#numbers, _separator=", " }:{{$name of $count}}]]
local model = {
	numbers = {
		{ name="one" },
		{ name="two" },
		{ name="three" },
	}
}
-- res: "one of 3, two of 3, three of 3"
```


The iter function takes a numeric argument and applies a template so many times.

```lua
-- model used in the following examples
local model = {
	numbers = {
		{ name="one" },
		{ name="two" },
		{ name="three" },
	}
}

-- @iter can be used for an explicit number of repetitions:
local temp = [[@iter{ "3" }:{{repeat $i1 }}]]
-- res: "repeat 1 repeat 2 repeat 3 "

-- again, _separator works:
local temp = [[@iter{ "3", _separator=", " }:{{repeat $i1}}]]
-- res: "repeat 1, repeat 2, repeat 3"

-- @iter can take an array item; it will use the length of that item:
local temp = [[@iter{ numbers, _separator=", " }:{{repeat $i1}}]]
-- res: "repeat 1, repeat 2, repeat 3"

-- @iter can take a range for start and end values:
local temp = [[@iter{ ["2", "3"] }:{{repeat $i1 }}]]
-- res: "repeat 2 repeat 3 "

-- the range can also be determined by an array whose length gets used
local temp = [[@iter{ ["2", numbers], _separator=", " }:{{repeat $i1}}]]
-- res: "repeat 2, repeat 3"
```
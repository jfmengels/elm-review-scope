# elm-review-scope

Provides a helper for [`elm-review`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/) that automatically collects information about the scope.

The `Scope` module collects information about where a variable comes from. It answers questions like "Was `foo` defined in the current module? If not, which module does it come from?". `Scope` looks at dependencies and other imported modules to give you the best answer, and follows import aliases.

This module is designed to work `jfmengels/elm-review` version `2.x.y`.

## The problem

Say you want to write a rule forbidding the use of a function, like `Html.map`.
You would look for expressions like `Expression.FunctionOrValue [ "Html" ] "map"` and report them.

What if the `map` was imported using `import Html exposing (map)`?
Then the rule would not detect the function use.
Basically you wish to report at least all of the following patterns:

```elm
import Html
a = Html.map someHtml

----
import Html exposing (map)
a = map someHtml

----
import Html exposing (..)
a = map someHtml

----
import Html as H
a = H.map someHtml

-- but not
import Html exposing (..)
map = someThing
a = map someHtml
```

Doing so requires a lot of tedious tracking of imports and variables declarations.
The `Scope` module handles this all automatically for you


## Documentation

You can view the docs at https://elm-doc-preview.netlify.com/?repo=jfmengels/elm-review-scope.


## Example use for modules rules

**Note**: Because module rules don't have the knowledge of what is exposed in the modules from the project that are being imported, you will not get the correct answer when you request the `realModuleName` of an element that was imported through `import A exposing (..)` or a type imported through `import A exposing (B(..))`.

If this is important to you, then you should turn your rule into a project rule, which will correctly get this information.

This example forbids using `Html.button` except in the `Button` module.

```elm
import Elm.Syntax.Expression exposing (Expression(..))
import Elm.Syntax.Node as Node exposing (Node)
import Review.Rule as Rule exposing (Direction, Error, Rule)
import Scope

rule : Rule
rule =
    Rule.newModuleRuleSchema "NoHtmlButton" initialContext
        -- Scope.addModuleVisitors should be added before your own visitors
        |> Scope.addModuleVisitors
        |> Rule.withExpressionVisitor expressionVisitor
        |> Rule.fromModuleRuleSchema
        |> Rule.ignoreErrorsForFiles [ "src/Button.elm" ]

type alias Context =
    -- Scope expects a context with a record, containing the `scope` field.
    { scope : Scope.ModuleContext
    -- ...other fields
    }

initialContext : Context
initialContext =
    { scope = Scope.initialModuleContext
    -- ...other fields
    }

expressionVisitor : Node Expression -> Direction -> Context -> ( List (Error {}), Context )
expressionVisitor node direction context =
    case ( direction, Node.value node ) of
        ( Rule.OnEnter, FunctionOrValue moduleName "button" ) ->
            if Scope.realModuleName context.scope "button" moduleName == [ "Html" ] then
                ( [ Rule.error
                        { message = "Do not use `Html.button` directly"
                        , details = [ "At fruits.com, we've built a nice `Button` module that suits our needs better. Using this module instead of `Html.button` ensures we have a consistent button experience across the website." ]
                        }
                        (Node.range node)
                  ]
                , context
                )

            else
                ( [], context )

        _ ->
            ( [], context )
```

## Example use for project rules

**Note**: `Scope.addProjectVisitors` will automatically add `Review.Rule.withContextFromImportedModules`.

We are taking the same example as for the module rule.

```elm
import Elm.Syntax.Expression exposing (Expression(..))
import Elm.Syntax.Node as Node exposing (Node)
import Review.Rule as Rule exposing (Direction, Error, Rule)
import Scope

rule : Rule
rule =
    Rule.newProjectRuleSchema "NoHtmlButton" initialProjectContext
        -- Scope.addProjectVisitors should be added before your own visitors
        |> Scope.addProjectVisitors
        |> Rule.withModuleVisitor moduleVisitor
        |> Rule.withModuleContext
            { fromProjectToModule = fromProjectToModule
            , fromModuleToProject = fromModuleToProject
            , foldProjectContexts = foldProjectContexts
            }
        |> Rule.fromProjectRuleSchema
        |> Rule.ignoreErrorsForFiles [ "src/Button.elm" ]


moduleVisitor : Rule.ModuleRuleSchema {} ModuleContext -> Rule.ModuleRuleSchema { hasAtLeastOneVisitor : () } ModuleContext
moduleVisitor schema =
    schema
        -- We can use the same `expressionVisitor` as for the module rule example
        |> Rule.withExpressionVisitor expressionVisitor

type alias ProjectContext =
    -- Scope expects a context with a record, containing the `scope` field.
    { scope : Scope.ModuleContext
    -- ...other fields
    }


type alias ModuleContext =
    { scope : Scope.ModuleContext
    -- ...other fields
    }


initialProjectContext : ProjectContext
initialProjectContext =
    { scope = Scope.initialProjectContext
    -- ...other fields
    }


fromProjectToModule : Rule.ModuleKey -> Node ModuleName -> ProjectContext -> ModuleContext
fromProjectToModule moduleKey moduleName projectContext =
    { scope = Scope.fromProjectToModule projectContext.scope
    -- ...other fields
    }


fromModuleToProject : Rule.ModuleKey -> Node ModuleName -> ModuleContext -> ProjectContext
fromModuleToProject moduleKey moduleName moduleContext =
    { scope = Scope.fromModuleToProject moduleName moduleContext.scope
    -- ...other fields
    }


foldProjectContexts : ProjectContext -> ProjectContext -> ProjectContext
foldProjectContexts newContext previousContext =
    { scope = Scope.foldProjectContexts newContext.scope previousContext.scope
    -- ...other fields
    }
```


## Why this is not part of elm-review

This is not part of `elm-review` because the API is still immature and very likely to break several times.

Every breaking change would require a new major version of `elm-review`, and every new major version would entail:
  1. Publishing a new version of the CLI that works with that major version of `elm-review`
  2. That every package for `elm-review` publishes a new version that works with `elm-review`
  3. Users not being able to use the next major version of `elm-review` until all the dependencies they use that themselves depend on `elm-review` have upgraded to the next major version. This is due to Elm not allowing duplicate dependencies with different major versions when building applications. **This is the point that worries me most**. For this same reason, if you publish a package for `elm-review`, I would urge you to vendor your dependencies, so as to prevent people from being blocked from upgrading because a new major version of the dependency has been released.

The current API is still minimal, so what is in there actually is probably mature, but future additions to this module are likely to go through several iterations.


## Why this is not published as an Elm package

If the module gets published as a stand-alone package, and several packages start depending on it, then problem n°3 described above becomes a problem again.

If the module gets exposed as part of a review package, then if another package does the same thing or the user has copied this package too for their own custom rules, then it is possible to get into module naming conflicts, which is not ideal.


## How you are supposed to use this package

The way to use this is to copy and paste the `Scope` module into your project.

I would really like you to **NOT publish this as a package**, and to **NOT expose this module** as part of your package. It is alright to publish a package using and containing this module, but without exposing it. Otherwise, we'll run into problem n°3 again.


## Request for help

This module does a lot of work, but I believe it is still missing some data and can be confused by several constructs of the source code. If you notice a problem, please open an issue!

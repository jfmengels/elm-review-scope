module ScopeTest exposing (all)

import Elm.Syntax.Declaration as Declaration exposing (Declaration)
import Elm.Syntax.Expression as Expression exposing (Expression)
import Elm.Syntax.Node as Node exposing (Node(..))
import Elm.Syntax.TypeAnnotation as TypeAnnotation exposing (TypeAnnotation)
import Fixtures.Dependencies as Dependencies
import Review.Project as Project exposing (Project)
import Review.Rule as Rule exposing (Error, Rule)
import Review.Test
import Scope
import Test exposing (Test, test)


all : Test
all =
    Test.describe "Scope"
        [ realModuleNameTestsForModuleRule
        , realModuleNameTestsForProjectRule
        ]


realModuleNameTestsForModuleRule : Test
realModuleNameTestsForModuleRule =
    Test.describe "Scope.realModuleName (module rule)"
        [ test "should indicate that module from which a function or value comes from, with knowledge of what is in other modules" <|
            \() ->
                """module A exposing (..)
import Bar as Baz exposing (baz)
import ExposesSomeThings exposing (..)
import ExposesEverything exposing (..)
import Foo.Bar
import Html exposing (..)
import Http exposing (get)

localValue = 1

a : SomeCustomType -> SomeTypeAlias -> SomeOtherTypeAlias -> NonExposedCustomType
a = localValue
    unknownValue
    exposedElement
    nonExposedElement
    elementFromExposesEverything
    VariantA
    Foo.bar
    Foo.Bar
    Baz.foo
    baz
    button
    Http.get
    get
    always
    True
    Just
"""
                    |> Review.Test.runWithProjectData project moduleRule
                    |> Review.Test.expectErrors
                        [ Review.Test.error
                            { message = """
<nothing>.SomeCustomType -> <nothing>.SomeCustomType
<nothing>.SomeTypeAlias -> <nothing>.SomeTypeAlias
<nothing>.SomeOtherTypeAlias -> <nothing>.SomeOtherTypeAlias
<nothing>.NonExposedCustomType -> <nothing>.NonExposedCustomType
<nothing>.localValue -> <nothing>.localValue
<nothing>.unknownValue -> <nothing>.unknownValue
<nothing>.exposedElement -> <nothing>.exposedElement
<nothing>.nonExposedElement -> <nothing>.nonExposedElement
<nothing>.elementFromExposesEverything -> <nothing>.elementFromExposesEverything
<nothing>.VariantA -> <nothing>.VariantA
Foo.bar -> Foo.bar
Foo.Bar -> Foo.Bar
Baz.foo -> Bar.foo
<nothing>.baz -> Bar.baz
<nothing>.button -> Html.button
Http.get -> Http.get
<nothing>.get -> Http.get
<nothing>.always -> Basics.always
<nothing>.True -> Basics.True
<nothing>.Just -> Maybe.Just"""
                            , details = [ "details" ]
                            , under = "module"
                            }
                        ]
        ]


realModuleNameTestsForProjectRule : Test
realModuleNameTestsForProjectRule =
    Test.describe "Scope.realModuleName (project rule)"
        [ test "should indicate that module from which a function or value comes from, with knowledge of what is in other modules" <|
            \() ->
                [ """module A exposing (..)
import Bar as Baz exposing (baz)
import ExposesSomeThings exposing (..)
import ExposesEverything exposing (..)
import Foo.Bar
import Html exposing (..)
import Http exposing (get)
import Something.B as Something
import Something.C as Something

localValue = 1
localValueValueToBeShadowed = 1
type Msg = SomeMsgToBeShadowed

a : SomeCustomType -> SomeTypeAlias -> SomeOtherTypeAlias -> NonExposedCustomType
a = localValue
    localValueValueToBeShadowed
    SomeMsgToBeShadowed
    SomeOtherMsg
    Something.b
    Something.c
    Something.BAlias
    Something.Foo
    Something.Bar
    unknownValue
    exposedElement
    nonExposedElement
    elementFromExposesEverything
    VariantA
    Foo.bar
    Foo.Bar
    Baz.foo
    baz
    button
    Http.get
    get
    always
    True
    Just
""", """module ExposesSomeThings exposing (SomeOtherTypeAlias, exposedElement)
type NonExposedCustomType = Variant
type alias SomeOtherTypeAlias = {}
exposedElement = 1
nonExposedElement = 2
""", """module ExposesEverything exposing (..)
type SomeCustomType = VariantA | VariantB
type alias SomeTypeAlias = {}
type Msg = SomeMsgToBeShadowed | SomeOtherMsg
elementFromExposesEverything = 1
localValueValueToBeShadowed = 1
""", """module Something.B exposing (..)
b = 1
type Foo = Bar
type alias BAlias = {}
""", """module Something.C exposing (..)
c = 1
""" ]
                    |> Review.Test.runOnModulesWithProjectData project projectRule
                    |> Review.Test.expectErrorsForModules
                        [ ( "A"
                          , [ Review.Test.error
                                { message = """
<nothing>.SomeCustomType -> ExposesEverything.SomeCustomType
<nothing>.SomeTypeAlias -> ExposesEverything.SomeTypeAlias
<nothing>.SomeOtherTypeAlias -> ExposesSomeThings.SomeOtherTypeAlias
<nothing>.NonExposedCustomType -> <nothing>.NonExposedCustomType
<nothing>.localValue -> <nothing>.localValue
<nothing>.localValueValueToBeShadowed -> <nothing>.localValueValueToBeShadowed
<nothing>.SomeMsgToBeShadowed -> <nothing>.SomeMsgToBeShadowed
<nothing>.SomeOtherMsg -> ExposesEverything.SomeOtherMsg
Something.b -> Something.B.b
Something.c -> Something.C.c
Something.BAlias -> Something.B.BAlias
Something.Foo -> Something.B.Foo
Something.Bar -> Something.B.Bar
<nothing>.unknownValue -> <nothing>.unknownValue
<nothing>.exposedElement -> ExposesSomeThings.exposedElement
<nothing>.nonExposedElement -> <nothing>.nonExposedElement
<nothing>.elementFromExposesEverything -> ExposesEverything.elementFromExposesEverything
<nothing>.VariantA -> ExposesEverything.VariantA
Foo.bar -> Foo.bar
Foo.Bar -> Foo.Bar
Baz.foo -> Bar.foo
<nothing>.baz -> Bar.baz
<nothing>.button -> Html.button
Http.get -> Http.get
<nothing>.get -> Http.get
<nothing>.always -> Basics.always
<nothing>.True -> Basics.True
<nothing>.Just -> Maybe.Just"""
                                , details = [ "details" ]
                                , under = "module"
                                }
                            ]
                          )
                        , ( "ExposesSomeThings"
                          , [ Review.Test.error
                                { message = ""
                                , details = [ "details" ]
                                , under = "module"
                                }
                            ]
                          )
                        , ( "ExposesEverything"
                          , [ Review.Test.error
                                { message = ""
                                , details = [ "details" ]
                                , under = "module"
                                }
                            ]
                          )
                        , ( "Something.B"
                          , [ Review.Test.error
                                { message = ""
                                , details = [ "details" ]
                                , under = "module"
                                }
                            ]
                          )
                        , ( "Something.C"
                          , [ Review.Test.error
                                { message = ""
                                , details = [ "details" ]
                                , under = "module"
                                }
                            ]
                          )
                        ]
        ]


type alias ModuleContext =
    { scope : Scope.ModuleContext
    , text : String
    }


project : Project
project =
    Project.new
        |> Project.addDependency Dependencies.elmCore
        |> Project.addDependency Dependencies.elmHtml


projectRule : Rule
projectRule =
    Rule.newProjectRuleSchema "TestRule" { scope = Scope.initialProjectContext }
        |> Scope.addProjectVisitors
        |> Rule.withModuleVisitor moduleVisitor
        |> Rule.withModuleContext
            { fromProjectToModule =
                \_ _ projectContext ->
                    { scope = Scope.fromProjectToModule projectContext.scope
                    , text = ""
                    }
            , fromModuleToProject =
                \_ moduleNameNode moduleContext ->
                    { scope = Scope.fromModuleToProject moduleNameNode moduleContext.scope
                    }
            , foldProjectContexts = \a b -> { scope = Scope.foldProjectContexts a.scope b.scope }
            }
        |> Rule.fromProjectRuleSchema


moduleRule : Rule
moduleRule =
    Rule.newModuleRuleSchema "TestRule" { scope = Scope.initialModuleContext, text = "" }
        |> Scope.addModuleVisitors
        |> moduleVisitor
        |> Rule.fromModuleRuleSchema


moduleVisitor : Rule.ModuleRuleSchema schemaState ModuleContext -> Rule.ModuleRuleSchema { schemaState | hasAtLeastOneVisitor : () } ModuleContext
moduleVisitor schema =
    schema
        |> Rule.withDeclarationVisitor declarationVisitor
        |> Rule.withExpressionVisitor expressionVisitor
        |> Rule.withFinalModuleEvaluation finalEvaluation


declarationVisitor : Node Declaration -> Rule.Direction -> ModuleContext -> ( List nothing, ModuleContext )
declarationVisitor node direction context =
    case ( direction, Node.value node ) of
        ( Rule.OnEnter, Declaration.FunctionDeclaration function ) ->
            case function.signature |> Maybe.map (Node.value >> .typeAnnotation) of
                Nothing ->
                    ( [], context )

                Just typeAnnotation ->
                    ( [], { context | text = context.text ++ "\n" ++ typeAnnotationNames context.scope typeAnnotation } )

        _ ->
            ( [], context )


typeAnnotationNames : Scope.ModuleContext -> Node TypeAnnotation -> String
typeAnnotationNames scope typeAnnotation =
    case Node.value typeAnnotation of
        TypeAnnotation.GenericType name ->
            "<nothing>." ++ name ++ " -> <generic>"

        TypeAnnotation.Typed (Node _ ( moduleName, typeName )) typeParameters ->
            -- Elm.Type.Type (String.join "." moduleName ++ "." ++ typeName) (List.map syntaxTypeAnnotationToDocsType typeParameters)
            let
                nameInCode : String
                nameInCode =
                    case moduleName of
                        [] ->
                            "<nothing>." ++ typeName

                        _ ->
                            String.join "." moduleName ++ "." ++ typeName

                realName : String
                realName =
                    case Scope.realModuleName scope typeName moduleName of
                        [] ->
                            "<nothing>." ++ typeName

                        moduleName_ ->
                            String.join "." moduleName_ ++ "." ++ typeName
            in
            nameInCode ++ " -> " ++ realName

        TypeAnnotation.Unit ->
            "unknown"

        TypeAnnotation.Tupled typeAnnotationTypeAnnotationSyntaxElmNodeNodeSyntaxElmListList ->
            "unknown"

        TypeAnnotation.Record recordDefinitionTypeAnnotationSyntaxElm ->
            "unknown"

        TypeAnnotation.GenericRecord stringStringNodeNodeSyntaxElm recordDefinitionTypeAnnotationSyntaxElmNodeNodeSyntaxElm ->
            "unknown"

        TypeAnnotation.FunctionTypeAnnotation arg returnType ->
            typeAnnotationNames scope arg ++ "\n" ++ typeAnnotationNames scope returnType


expressionVisitor : Node Expression -> Rule.Direction -> ModuleContext -> ( List nothing, ModuleContext )
expressionVisitor node direction context =
    case ( direction, Node.value node ) of
        ( Rule.OnEnter, Expression.FunctionOrValue moduleName name ) ->
            let
                nameInCode : String
                nameInCode =
                    case moduleName of
                        [] ->
                            "<nothing>." ++ name

                        _ ->
                            String.join "." moduleName ++ "." ++ name

                realName : String
                realName =
                    case Scope.realModuleName context.scope name moduleName of
                        [] ->
                            "<nothing>." ++ name

                        moduleName_ ->
                            String.join "." moduleName_ ++ "." ++ name
            in
            ( [], { context | text = context.text ++ "\n" ++ nameInCode ++ " -> " ++ realName } )

        _ ->
            ( [], context )


finalEvaluation : ModuleContext -> List (Error {})
finalEvaluation context =
    [ Rule.error { message = context.text, details = [ "details" ] }
        { start = { row = 1, column = 1 }
        , end = { row = 1, column = 7 }
        }
    ]

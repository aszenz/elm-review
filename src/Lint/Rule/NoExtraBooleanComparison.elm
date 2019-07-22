module Lint.Rule.NoExtraBooleanComparison exposing (rule)

{-| Forbid the use of boolean comparisons that can be simplified.


# Rule

@docs rule

-}

import Elm.Syntax.Expression as Expression exposing (Expression(..))
import Elm.Syntax.Node as Node exposing (Node)
import Lint.Rule as Rule exposing (Error, Rule)


{-| Forbid the use of boolean comparisons that can be simplified.

    config =
        [ ( Critical, NoExtraBooleanComparison.rule )
        ]


## Fail

    if someBooleanValue == True then
        a

    else
        b

    if someBooleanValue == False then
        a

    else
        b


## Success

    if someBooleanValue then
        a

    else
        b

    if not someBooleanValue then
        a

    else
        b

-}
rule : Rule
rule =
    Rule.newSchema "NoExtraBooleanComparison"
        |> Rule.withSimpleExpressionVisitor expressionVisitor
        |> Rule.fromSchema


error : Node a -> String -> Error
error node comparedValue =
    Rule.error
        ("Unnecessary comparison with `" ++ comparedValue ++ "`")
        (Node.range node)


expressionVisitor : Node Expression -> List Error
expressionVisitor node =
    case Node.value node of
        Expression.OperatorApplication operator _ left right ->
            if isEqualityOperator operator then
                List.filterMap isTrueOrFalse [ left, right ]
                    |> List.map (error node)

            else
                []

        _ ->
            []


isEqualityOperator : String -> Bool
isEqualityOperator operator =
    operator == "==" || operator == "/="


isTrueOrFalse : Node Expression -> Maybe String
isTrueOrFalse node =
    case Node.value node of
        FunctionOrValue [] functionOrValue ->
            if functionOrValue == "True" || functionOrValue == "False" then
                Just functionOrValue

            else
                Nothing

        _ ->
            Nothing

module Review.Test.ErrorMessage exposing
    ( ExpectedErrorData
    , parsingFailure, messageMismatch, emptyDetails, unexpectedDetails, wrongLocation, didNotExpectErrors
    , underMismatch, expectedMoreErrors, tooManyErrors, locationNotFound, locationIsAmbiguousInSourceCode
    , needToUsedExpectErrorsForModules, duplicateModuleName, unknownModulesInExpectedErrors
    , missingFixes, unexpectedFixes, fixedCodeMismatch, unchangedSourceAfterFix, invalidSourceAfterFix, hasCollisionsInFixRanges
    )

{-| Error messages for the `Review.Test` module.


# Error messages

@docs ExpectedErrorData
@docs parsingFailure, messageMismatch, emptyDetails, unexpectedDetails, wrongLocation, didNotExpectErrors
@docs underMismatch, expectedMoreErrors, tooManyErrors, locationNotFound, locationIsAmbiguousInSourceCode
@docs needToUsedExpectErrorsForModules, duplicateModuleName, unknownModulesInExpectedErrors
@docs missingFixes, unexpectedFixes, fixedCodeMismatch, unchangedSourceAfterFix, invalidSourceAfterFix, hasCollisionsInFixRanges

-}

import Elm.Syntax.Range exposing (Range)
import ListExtra
import Review.Rule as Rule exposing (Error)


{-| An expectation for an error. Use [`error`](#error) to create one.
-}
type alias ExpectedErrorData =
    { message : String
    , details : List String
    , under : String
    }


type alias SourceCode =
    String



-- ERROR MESSAGES


didNotExpectErrors : String -> List Error -> String
didNotExpectErrors moduleName errors =
    """DID NOT EXPECT ERRORS

I expected no errors for module `""" ++ moduleName ++ """` but found:

""" ++ listErrorMessagesAndPositions errors


parsingFailure : Bool -> { index : Int, source : String } -> String
parsingFailure isOnlyFile { index, source } =
    let
        title : String
        title =
            "TEST SOURCE CODE PARSING ERROR"

        hint : String
        hint =
            """Hint: Maybe you forgot to add the module definition at the top, like:

  `module A exposing (..)`"""

        details : String
        details =
            if isOnlyFile then
                "I could not parse the test source code, because it was not valid Elm code."

            else
                """I could not parse one of the test source codes, because it was not valid
Elm code.

The source code in question is the one at index """
                    ++ String.fromInt index
                    ++ """ starting with:

  `"""
                    ++ (String.join "" <| List.take 1 <| String.split "\n" <| String.trim source)
                    ++ "`"
    in
    title ++ "\n\n" ++ details ++ "\n\n" ++ hint


messageMismatch : ExpectedErrorData -> Error -> String
messageMismatch expectedError error =
    """UNEXPECTED ERROR MESSAGE

I was looking for the error with the following message:

  """ ++ wrapInQuotes expectedError.message ++ """

but I found the following error message:

  """ ++ wrapInQuotes (Rule.errorMessage error)


underMismatch : Error -> { under : String, codeAtLocation : String } -> String
underMismatch error { under, codeAtLocation } =
    """UNEXPECTED ERROR LOCATION

I found an error with the following message:

  """ ++ wrapInQuotes (Rule.errorMessage error) ++ """

which I was expecting, but I found it under:

  """ ++ formatSourceCode codeAtLocation ++ """

when I was expecting it under:

  """ ++ formatSourceCode under ++ """

Hint: Maybe you're passing the `Range` of a wrong node when
calling `Rule.error`."""


unexpectedDetails : List String -> Error -> String
unexpectedDetails expectedDetails error =
    """UNEXPECTED ERROR DETAILS

I found an error with the following message:

  """ ++ wrapInQuotes (Rule.errorMessage error) ++ """

which I was expecting, but its details were:

  """ ++ formatDetails (Rule.errorDetails error) ++ """

when I was expecting them to be:

  """ ++ formatDetails expectedDetails


emptyDetails : Error -> String
emptyDetails error =
    """EMPTY ERROR DETAILS

I found an error with the following message:

  """ ++ wrapInQuotes (Rule.errorMessage error) ++ """

but its details were empty. I require having details as I believe they will
help the user who encounters the problem.

The details could:
- explain what the problem is
- give suggestions on how to solve the problem or alternatives"""


formatDetails : List String -> String
formatDetails details =
    case details of
        [ detail ] ->
            wrapInQuotes detail

        details_ ->
            details_
                |> List.map (\str -> "  " ++ str)
                |> String.join "\n\n"
                |> (\str -> "```\n" ++ str ++ "\n  ```")


wrongLocation : Error -> Range -> String -> String
wrongLocation error range under =
    """UNEXPECTED ERROR LOCATION

I was looking for the error with the following message:

  """ ++ wrapInQuotes (Rule.errorMessage error) ++ """

under the following code:

  """ ++ formatSourceCode under ++ """

and I found it, but the exact location you specified is not the one I found.

I was expecting the error at:

  """ ++ rangeAsString range ++ """

but I found it at:

  """ ++ rangeAsString (Rule.errorRange error)


expectedMoreErrors : String -> List ExpectedErrorData -> String
expectedMoreErrors moduleName missingExpectedErrors =
    let
        numberOfErrors : Int
        numberOfErrors =
            List.length missingExpectedErrors
    in
    """RULE REPORTED LESS ERRORS THAN EXPECTED

I expected to see """
        ++ (String.fromInt numberOfErrors ++ " more " ++ pluralizeErrors numberOfErrors ++ " for module `" ++ moduleName ++ "`:\n\n")
        ++ (missingExpectedErrors
                |> List.map expectedErrorToString
                |> String.join "\n"
           )


tooManyErrors : String -> List Error -> String
tooManyErrors moduleName extraErrors =
    let
        numberOfErrors : Int
        numberOfErrors =
            List.length extraErrors
    in
    """RULE REPORTED MORE ERRORS THAN EXPECTED

I found """
        ++ (String.fromInt numberOfErrors ++ " " ++ pluralizeErrors numberOfErrors ++ " too many for module `" ++ moduleName ++ "`:\n\n")
        ++ listErrorMessagesAndPositions extraErrors


locationNotFound : Error -> String
locationNotFound error =
    """COULD NOT FIND LOCATION FOR ERROR

I was looking for the error with the following message:

  """ ++ wrapInQuotes (Rule.errorMessage error) ++ """

and I found it, but the code it points to does not lead to anything:

  """ ++ rangeAsString (Rule.errorRange error) ++ """

Please try to have the error under the smallest region that makes sense.
This will be the most helpful for the person who reads the error message."""


locationIsAmbiguousInSourceCode : SourceCode -> Error -> String -> List Int -> String
locationIsAmbiguousInSourceCode sourceCode error under occurrencesInSourceCode =
    """AMBIGUOUS ERROR LOCATION

Your test passes, but where the message appears is ambiguous.

You are looking for the following error message:

  """ ++ wrapInQuotes (Rule.errorMessage error) ++ """

and expecting to see it under:

  """ ++ formatSourceCode under ++ """

I found """ ++ String.fromInt (List.length occurrencesInSourceCode) ++ """ locations where that code appeared. Please use
`Review.Rule.atExactly` to make the part you were targetting unambiguous.

Tip: I found them at:
""" ++ listOccurrencesAsLocations sourceCode under occurrencesInSourceCode


needToUsedExpectErrorsForModules : String
needToUsedExpectErrorsForModules =
    """AMBIGUOUS MODULE FOR ERROR

You gave me several modules, and you expect some errors. I need to know for
which module you expect these errors to be reported.

You should use `expectErrorsForModules` to do this:

  test "..." <|
    \\() ->
      [ \"\"\"
module A exposing (..)
-- someCode
\"\"\", \"\"\"
module B exposing (..)
-- someCode
\"\"\" ]
      |> Review.Test.runOnModules rule
      |> Review.Test.expectErrorsForModules
          [ ( "B", [ Review.Test.error someError ] )
          ]"""


duplicateModuleName : List String -> String
duplicateModuleName moduleName =
    """DUPLICATE MODULE NAMES

I found several modules named `""" ++ String.join "." moduleName ++ """` in the test source codes.

I expect all modules to be able to exist together in the same project,
but having several modules with the same name is not allowed by the Elm
compiler.

Please rename the modules so that they all have different names."""


unknownModulesInExpectedErrors : String -> String
unknownModulesInExpectedErrors moduleName =
    """UNKNOWN MODULES IN EXPECTED ERRORS

I expected errors for a module named `""" ++ moduleName ++ """` in the list passed to
`expectErrorsForModules`, but I couldn't find a module in the test source
codes named that way.

I assume that there was a mistake during the writing of the test. Please
match the names of the modules in the test source codes to the ones in the
expected errors list."""


missingFixes : ExpectedErrorData -> String
missingFixes expectedError =
    """MISSING FIXES

I expected that the error with the following message

  """ ++ wrapInQuotes expectedError.message ++ """

would provide some fixes, but I didn't find any.

Hint: Maybe you forgot to call `Rule.withFixes` on the error that you
created, or maybe the list of provided fixes was empty."""


unexpectedFixes : Error -> String
unexpectedFixes error =
    """UNEXPECTED FIXES

I expected that the error with the following message

  """ ++ wrapInQuotes (Rule.errorMessage error) ++ """

would not have any fixes, but it provided some.

Because the error provides fixes, I require providing the expected result
of the automatic fix. Otherwise, there is no way to know whether the fix
will result in a correct and in the intended result.

To fix this, you can call `Review.Test.whenFixed` on your error:

  Review.Test.error
      { message = "<message>"
      , details = "<details>"
      , under = "<under>"
      }
      |> Review.Test.whenFixed "<source code>\""""


fixedCodeMismatch : SourceCode -> SourceCode -> Error -> String
fixedCodeMismatch resultingSourceCode expectedSourceCode error =
    """FIXED CODE MISMATCH

I found a different fixed source code than expected for the error with the
following message:

  """ ++ wrapInQuotes (Rule.errorMessage error) ++ """

I found the following result after the fixes have been applied:

  """ ++ formatSourceCode resultingSourceCode ++ """

but I was expecting:

  """ ++ formatSourceCode expectedSourceCode


unchangedSourceAfterFix : Error -> String
unchangedSourceAfterFix error =
    """UNCHANGED SOURCE AFTER FIX

I got something unexpected when applying the fixes provided by the error
with the following message:

  """ ++ wrapInQuotes (Rule.errorMessage error) ++ """

I expected the fix to make some changes to the source code, but it resulted
in the same source code as before the fixes.

This is problematic because I will tell the user that this rule provides an
automatic fix, but I will have to disappoint them when I later find out it
doesn't do anything.

Hint: Maybe you inserted an empty string into the source code."""


invalidSourceAfterFix : Error -> SourceCode -> String
invalidSourceAfterFix error resultingSourceCode =
    """INVALID SOURCE AFTER FIX

I got something unexpected when applying the fixes provided by the error
with the following message:

  """ ++ wrapInQuotes (Rule.errorMessage error) ++ """

I was unable to parse the source code after applying the fixes. Here is
the result of the automatic fixing:

  """ ++ formatSourceCode resultingSourceCode ++ """

This is problematic because fixes are meant to help the user, and applying
this fix will give them more work to do. After the fix has been applied,
the problem should be solved and the user should not have to think about it
anymore. If a fix can not be applied fully, it should not be applied at
all."""


hasCollisionsInFixRanges : Error -> String
hasCollisionsInFixRanges error =
    """FOUND COLLISIONS IN FIX RANGES

I got something unexpected when applying the fixes provided by the error
with the following message:

  """ ++ wrapInQuotes (Rule.errorMessage error) ++ """

I found that some fixes were targeting (partially or completely) the same
section of code. The problem with that is that I can't determine which fix
to apply first, and the result will be different and potentially invalid
based on the order in which I apply these fixes.

For this reason, I require that the ranges (for replacing and removing) and
the positions (for inserting) of every fix to be mutually exclusive.

Hint: Maybe you duplicated a fix, or you targetted the wrong node for one
of your fixes."""



-- STYLIZING AND FORMATTING


formatSourceCode : String -> String
formatSourceCode string =
    let
        lines =
            String.lines string
    in
    if List.length lines == 1 then
        "`" ++ string ++ "`"

    else
        lines
            |> List.map
                (\str ->
                    if str == "" then
                        ""

                    else
                        "    " ++ str
                )
            |> String.join "\n"
            |> (\str -> "```\n" ++ str ++ "\n  ```")


listOccurrencesAsLocations : SourceCode -> String -> List Int -> String
listOccurrencesAsLocations sourceCode under occurrences =
    occurrences
        |> List.map
            (\occurrence ->
                occurrence
                    |> positionAsRange sourceCode under
                    |> rangeAsString
                    |> (++) "  - "
            )
        |> String.join "\n"


positionAsRange : SourceCode -> String -> Int -> Range
positionAsRange sourceCode under position =
    let
        linesBeforeAndIncludingPosition : List String
        linesBeforeAndIncludingPosition =
            sourceCode
                |> String.slice 0 position
                |> String.lines

        startRow : Int
        startRow =
            List.length linesBeforeAndIncludingPosition

        startColumn : Int
        startColumn =
            linesBeforeAndIncludingPosition
                |> ListExtra.last
                |> Maybe.withDefault ""
                |> String.length
                |> (+) 1

        linesInUnder : List String
        linesInUnder =
            String.lines under

        endRow : Int
        endRow =
            startRow + List.length linesInUnder - 1

        endColumn : Int
        endColumn =
            if startRow == endRow then
                startColumn + String.length under

            else
                linesInUnder
                    |> ListExtra.last
                    |> Maybe.withDefault ""
                    |> String.length
                    |> (+) 1
    in
    { start =
        { row = startRow
        , column = startColumn
        }
    , end =
        { row = endRow
        , column = endColumn
        }
    }


listErrorMessagesAndPositions : List Error -> String
listErrorMessagesAndPositions errors =
    errors
        |> List.map errorMessageAndPosition
        |> String.join "\n"


errorMessageAndPosition : Error -> String
errorMessageAndPosition error =
    "  - " ++ wrapInQuotes (Rule.errorMessage error) ++ "\n    at " ++ rangeAsString (Rule.errorRange error)


expectedErrorToString : ExpectedErrorData -> String
expectedErrorToString expectedError =
    "  - " ++ wrapInQuotes expectedError.message


wrapInQuotes : String -> String
wrapInQuotes string =
    "`" ++ string ++ "`"


rangeAsString : Range -> String
rangeAsString { start, end } =
    "{ start = { row = " ++ String.fromInt start.row ++ ", column = " ++ String.fromInt start.column ++ " }, end = { row = " ++ String.fromInt end.row ++ ", column = " ++ String.fromInt end.column ++ " } }"


pluralizeErrors : Int -> String
pluralizeErrors n =
    if n == 1 then
        "error"

    else
        "errors"

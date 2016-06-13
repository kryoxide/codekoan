module Handler.Submit where

import Import

import Thesis.Tokenizer
import Thesis.Search
import Thesis.Data.Text.PositionRange
import Thesis.Data.Stackoverflow.Answer
import Thesis.Data.Stackoverflow.Question
import Thesis.Data.Stackoverflow.Dictionary as Dict

import Lib (prettyPrintOutput)

getSubmitR :: Handler Html
getSubmitR = do
  (formWidget, formEnctype) <- generateFormPost submitCodeForm
  let result = Nothing :: Maybe (Maybe String, Maybe Widget)
  defaultLayout $ do
    setTitle "Code Analysis"
    $(widgetFile "submit")

postSubmitR :: Handler Html
postSubmitR = do
  ((formResult, formWidget), formEnctype) <- runFormPost submitCodeForm
  foundation <- getYesod
  let index = appIndex foundation
  let result =
        case formResult of
          FormSuccess (txt, n) -> 
            let tks = processAndTokenize java txt
                sortOnSimilarity :: Ord x => [(a,b,c,x)] -> [(a,b,c,x)]
                sortOnSimilarity = sortOn (\(_,_,_,similarity) -> similarity)
                filterMatchLength = filter $ \(_,ts,_,_) -> length ts > 10
                searchResult = (filterMatchLength . sortOnSimilarity) <$> findMatches index n txt
                buildResultWidget = resultsWidget (resultWidget (langText txt))
            in Just (show <$> tks, buildResultWidget <$> searchResult)
          _ -> Nothing
  defaultLayout $ do
    setTitle "Code Analysis"
    $(widgetFile "submit")

resultsWidget :: (a -> Widget) -> [a] -> Widget
resultsWidget f ws = do
  sequence $ f <$> ws
  return ()

-- | Build a nicely formatted output widget for a search result
resultWidget :: Show t
                => Text -- ^ The query code to which the range pertains
             -> (PositionRange, [t], AnswerId, Int) -- ^ Search result
             -> Widget 
resultWidget txt (range, tokens, aId@AnswerId{..}, score) = do
  dict <- appDict <$> getYesod
  let questionId = Dict.answerParent dict aId
  [whamlet|
    <h3> Found a hit in answer #{answerIdInt}, distance is #{score}:

    $maybe qId <- questionId
      <a href="http://stackoverflow.com/questions/#{show $ questionIdInt qId}">
        Link to question
    <br>
    <code>
      #{textInRange range txt}
    <h4> Matched tokens:
      #{show tokens}
         |]

submitCodeForm :: Html
               -> MForm Handler (FormResult (LanguageText Java, Int), Widget)
submitCodeForm = renderTable $ submitCodeAForm

submitCodeAForm :: AForm Handler (LanguageText Java, Int)
submitCodeAForm = (,)
                  <$> (langText <$> areq textareaField "Your java code" Nothing)
                  <*> areq intField "Sensitivity" (Just 3)
  where
    langText = LanguageText . unTextarea

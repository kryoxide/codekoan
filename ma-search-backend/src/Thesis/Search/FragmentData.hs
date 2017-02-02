{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
module Thesis.Search.FragmentData where

import Thesis.Data.Stackoverflow.Answer

class (Ord a) => FragmentData a where
  printFragData :: a -> String
  fragDataTokenLength :: a -> Int

instance FragmentData (Int, Int) where
  printFragData (ann,_) = show ann
  fragDataTokenLength (_, l) = l

instance FragmentData AnswerFragmentMetaData where
  printFragData (AnswerFragmentMetaData AnswerFragmentId{..} _) =
    (show $ answerIdInt fragmentAnswerId) ++ " (" ++ (show $ fragmentId) ++ ")"
  fragDataTokenLength AnswerFragmentMetaData{..} = fragmentMetaSize
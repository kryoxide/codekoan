-- |
-- Description: Module for string NGrams and related functions
-- Maintainer: Christof Schramm
-- License: All rights reserved
-- Copyright: (c) Christof Schramm, 2016, 2017
-- Stability: Experimental
--
{-# LANGUAGE RecordWildCards #-}
module Thesis.Search.NGrams where

import qualified Data.Vector as V
import Data.List (sortOn)
-- | A list of n long nonoverlapping, contiguous subsequences of the given
-- sequence
ngrams :: Int -> V.Vector a -> [V.Vector a]
ngrams n dat = do
  (ngr, _, _) <- ngramTails n dat
  return ngr


allNGrams :: Int -> V.Vector a -> [V.Vector a]
allNGrams n dat = do
  (ngr, _, _) <- allNgramTails n dat
  return ngr

allNgramTails :: Int -> V.Vector a -> [(V.Vector a, Int, V.Vector a)]
allNgramTails n dat | n <= 0 = []
                    | otherwise =
  let result = sortOn ind $ concat $ do
        x <- [0..n-1]
        let dat' = V.drop x (dat)
        [shift x $ ngrs dat']
  in length result `seq` result
  where
    ngrs xs = ngramTails n xs
    shift k xs = do
      (a,b,c) <- xs
      return (a, b+k, c)
    ind (_, i, _) = i

-- | A list of n long nonoverlapping, contiguous subsequences of the given
-- sequence, paired with the remainder of the sequence starting with the
-- returned ngram.
--
-- So for example this for the string "abcdef" and 2-grams one of the values
-- returned by this function would be ("cd", 2, "cdef")
ngramTails :: Int -> V.Vector a -> [(V.Vector a, Int,  V.Vector a)]
ngramTails n dat = ngr 0 dat
  where
    ngr k xs | V.null xs = []
             | otherwise =
      let (ngram, rest) = V.splitAt n xs
      in if null rest && (length ngram < n)
         then []
         else (ngram, k, xs) : (ngr (k + n) rest)


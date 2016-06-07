{-# LANGUAGE TupleSections #-}
{-# LANGUAGE RecordWildCards #-}
module Thesis.Levenstein where

import Thesis.Trie

import qualified Data.Map as M

--------------------------------------------------------------------------------
--
-- Implementation of efficient Levenstein Automata

-- | A levenstein automaton for any indexable data structure. Take care, that
-- the levenSize is correct, otherwise the automaton will produce bad results.
data LevensteinAutomaton a =
  LevensteinAutomaton { levenSize :: Int -- ^ Size of the input string
                      , levenN :: Int    -- ^ Max number of tolerated errors
                      , levenIndex :: Int -> a -- ^ Indexing function for the
                                               -- given string
                      }

-- | A map from indices to values
newtype LevenState = LevenState {stateList :: [(Int,Int)]}
                   deriving (Show,Eq)

-- | The start state of the given levenstein automaton
startL :: Eq a => LevensteinAutomaton a -> LevenState
startL aut@(LevensteinAutomaton{..}) = LevenState $ values
  where
    n = min levenSize levenN
    values = zip [0..n] [0..n]

-- | Step a Levenstein State once. Takes O(levenN) steps to perform once as
-- there can only ever be 2*levenN + 1 fields in a state that have a value
-- less than or equal to levenN
stepL :: (Eq a) => LevensteinAutomaton a -> LevenState -> a -> LevenState
stepL LevensteinAutomaton{..} (LevenState []) _ = LevenState []
stepL LevensteinAutomaton{..} LevenState{..} x =
  LevenState $ reverse $ foldl f lst statesWithSuccessors
  where
    -- Successors of positions in the state. The last position has no successor
    successors = (Just <$> (tail stateList))++[Nothing]

    --  Pairs of state positions with their successor positions
    statesWithSuccessors = (zip stateList successors)

    -- If we can extend the state of the first position downwards, we do
    lst = case head stateList of
      (i,v) | v < levenN -> [(i, v+1)]
      _                  -> []

    f l ((i,v), succ) = let cost = if levenIndex i == x then 0 else 1
                            fromLeft = case l of
                              (_,v'):_ -> ((v'+1):)
                              _        -> id
                            fromTop = case succ of
                              Just (i',v') | i' == i+1 -> ((v'+1):)
                              _                        -> id
                            val = foldl1 min (fromTop $ fromLeft [v + cost])
                        in if i < levenSize && val <= levenN
                           then ((i+1),val):l
                           else l


-- | Predicate to determine if the given automaton state is accepting
acceptL :: LevensteinAutomaton a -> LevenState -> Bool
acceptL LevensteinAutomaton{..} LevenState{..} =
  case reverse stateList of
    [] -> False
    (i,v):_ -> i == levenSize

-- | Returns if the given levenstein state is an accepting state of the given
-- automaton
canAcceptL :: LevensteinAutomaton a -> LevenState -> Bool
canAcceptL aut LevenState{..} = if stateList == []
                                then False
                                else foldl1 min (snd <$> stateList) <= (levenN aut)

-- | If the state is an accepting state, return the levenstein distance of the input
acceptScoreL :: LevensteinAutomaton a -> LevenState -> Maybe Int
acceptScoreL LevensteinAutomaton{..} LevenState{..} =
  case reverse stateList of
    (i,v):_ | i == levenSize -> Just v
    _ -> Nothing

-- | Find all words accepted by the given levenstein automaton in the trie. The
-- number for each word is the word's levenstein distance to the given word.
lookupL :: (Ord a, Eq v) => LevensteinAutomaton a -> Trie a v -> [([a], v,Int)]
lookupL aut t | t == empty = []
              | otherwise = lookupL' aut t (startL aut)

-- | Helper function for 'lookupL'
lookupL' :: (Ord a, Eq v) => LevensteinAutomaton a -> Trie a v -> LevenState -> [([a], v, Int)]
lookupL' aut (LeafNode v) s = maybe [] ((:[]) . ([], v,)) (acceptScoreL aut s)
lookupL' aut (InnerNode mp) s | (not $ canAcceptL aut s) = []
                              | otherwise = do
                                              (c,t') <- M.toList mp
                                              (app c) <$> lookupL' aut t' (stepL aut s c)
  where
    app c (str, val, score) = (c:str, val, score)

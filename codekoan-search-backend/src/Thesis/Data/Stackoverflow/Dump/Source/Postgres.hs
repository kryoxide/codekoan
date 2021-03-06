-- |
-- Description: Conduit sources for stackoverflow db
-- Maintainer: Christof Schramm
-- License: All rights reserved
-- Copyright: (c) Christof Schramm, 2016, 2017
-- Stability: Experimental
--
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE OverloadedStrings #-}
module Thesis.Data.Stackoverflow.Dump.Source.Postgres where

import           Data.List (nub)

import           Control.Monad
import           Control.Monad.IO.Class
import           Data.Conduit hiding (connect)
import           Data.Text hiding (maximum)
import qualified Data.Vector as V
import           Database.PostgreSQL.Simple
import           Thesis.Data.Stackoverflow.Answer

-- | Create a source of 'StackoverflowPost's from an XML dump file
answerSource :: (MonadIO m) =>
                Connection -> Source m Answer
answerSource connection = go 0
  where
    chunkSize = 250 :: Int
    go n = do
      results <- liftIO $ query connection
                                "SELECT * FROM answers \
                                \WHERE answers.id > ? \
                                \ORDER BY answers.id LIMIT ?"
                                (n, chunkSize)
      let answers = do
            (aId, aBody, aRating, aParent) <- results
            return $ Answer (AnswerId aId)
                            aBody
                            aRating
                            aParent
          maxId = case results of
            [] -> Nothing
            _ -> Just . maximum $ (\(i, _, _, _) -> i) <$> results
      forM_ answers yield

      forM_ maxId go

-- | Count the number of answers, where the questions have the given tags.
answerWithTagsCount :: Connection -> [Text] -> IO Int
answerWithTagsCount connection tags = do
  results <- query connection "SELECT COUNT (*) \
                              \FROM answers AS a \
                              \JOIN (SELECT * FROM questions) as q \
                              \ON a.parent = q.id \
                              \WHERE ? <@ tags"
                              (Only $ V.fromList tags)
  case results of
    ((x:_):_) -> return x
    _ -> return 0

-- | Create a source of 'StackoverflowPost's that have all of a given list of
-- tags
answersWithTags :: MonadIO m => Connection -> [Text] -> Source m Answer
answersWithTags connection tags = go 0
  where
    chunkSize = 250 :: Int
    tagVector = V.fromList $ nub tags
    go n = do
      results <- liftIO $ query connection
                                "SELECT a.* \
                                \FROM (SELECT * FROM answers \
                                      \WHERE answers.id > ?) AS a \
                                \JOIN (SELECT * FROM questions) AS b \
                                \ON a.parent = b.id \
                                \WHERE ? <@ tags ORDER BY a.id LIMIT ?"
                                (n, tagVector, chunkSize)
      let answers = do
            (aId, aBody, aRating, aParent) <- results
            return $ Answer (AnswerId aId)
                            aBody
                            aRating
                            aParent
          maxId = case results of
            [] -> Nothing
            _ -> Just . maximum $ (\(i, _, _, _) -> i) <$> results

      forM_ answers yield

      forM_ maxId go

-- | Retrieve a certain number of unique, random answers from the DB 
answersWithTagsRandomOrder :: MonadIO m
                           => Connection
                           -> [Text]
                           -> Int
                           -> m (V.Vector Answer)
answersWithTagsRandomOrder connection tags n = do
  let tagVector = V.fromList $ nub tags
  results <- liftIO
             $ query connection
                     "SELECT a.* FROM \
                      \(SELECT * FROM answers WHERE answers.id > ?) AS a \
                      \JOIN (SELECT * FROM questions) AS b \
                      \ON a.parent = b.id \
                      \WHERE ? <@ tags \
                      \ORDER BY a.id \
                      \LIMIT ?"
                      (n, tagVector, n)
  let answers = do
        (aId, aBody, aRating, aParent) <- results
        return $ Answer (AnswerId aId) aBody aRating aParent
  return $ V.fromList answers

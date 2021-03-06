{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE OverloadedStrings#-}
module Thesis.Util.LoggingUtils where

import           Control.Monad.Logger

import           Control.Concurrent (myThreadId)
import qualified Data.ByteString.Char8 as BS
import           Data.Char (isDigit)
import           Data.Monoid ((<>))
import           Data.Time
import           System.IO
import           System.Log.FastLogger (fromLogStr)

runOutstreamLogging :: LoggingT m a -> m a
runOutstreamLogging  = (`runLoggingT` writeOutput)
  where
    writeOutput location source level str = do
      let handle = getHandle level
      formatted <- formatStr location source level str
      let formattedLogStr = (fromLogStr formatted)

      -- Determine timestamp only after log string has been completely evaluated
      time <- formattedLogStr `seq` getCurrentTime >>= utcToLocalZonedTime
      BS.hPutStrLn handle $ (BS.pack $ show time) <> " -- " <> formattedLogStr

      hFlush handle

    getHandle LevelError = stdout
    getHandle LevelWarn  = stdout
    getHandle _ = stdout


    formatStr location _ level str = do
      tId <- (dropWhile (not . isDigit)) . show  <$> myThreadId
      let threadIdString = "[" <> (toLogStr tId) <> "]"
      return $ threadIdString
               <> formatLevel level
               <> " :: " <> str <> " <<Source: "
               <> (toLogStr $ loc_package location) <> "/"
               <> (toLogStr $ loc_module location) <> " " <>
               (toLogStr $ (show $ loc_start location)) <> ">>" 

    formatLevel :: LogLevel -> LogStr
    formatLevel (LevelOther lvl) = "[" <> (toLogStr lvl) <> "]"
    formatLevel (LevelDebug) = "[Debug]"
    formatLevel (LevelInfo)  = "[Info]"
    formatLevel (LevelWarn)  = "[Warn]"
    formatLevel (LevelError) = "[Error]"


testLogging :: LoggingT IO ()
testLogging = do
  $(logDebug) "debugging"
  $(logError) "error"

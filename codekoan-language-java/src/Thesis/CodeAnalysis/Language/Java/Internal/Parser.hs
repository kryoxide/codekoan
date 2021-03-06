-- |
-- Copyright: Christof Schramm 2016
-- License: All rights reserved
--
-- This module provides internals for the java implementation, that are should
-- not be visible to other modules, except for testing or if you know exactly
-- what you are doing.
--
-- THIS INTERNAL MODULE CAN BE SUBJECT TO BREAKING CHANGE AT ANY TIME. DO NOT
-- USE IT IN STABLE CODE.

{-# LANGUAGE TupleSections #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE GADTs #-}
module Thesis.CodeAnalysis.Language.Java.Internal.Parser where

import           Control.Applicative ((<|>))
import           Data.Attoparsec.Text as AP
import           Data.Char
import qualified Data.Text as Text
import qualified Data.Vector as V
import Thesis.CodeAnalysis.Language.CommonTokenParsers
import Thesis.CodeAnalysis.Language.Internal
import Thesis.CodeAnalysis.Language.Java.Internal.Tokens
import Thesis.CodeAnalysis.Language.Java.Internal.Type



tokenizeJ :: LanguageText Java -> Maybe (TokenVector Token Java)
tokenizeJ LanguageText{..} = removeImports . buildTokenVector <$> parseResult
  where
    parseResult :: Maybe [(Int, Maybe Token)]
    parseResult = case AP.parseOnly (many' lenParser) langText of
      Right xs -> Just xs
      _ -> Nothing

    -- | Parse a token or skip an area (Nothing if skipped). Also yields the
    -- length of the
    lenParser :: Parser (Int, Maybe Token)
    lenParser = do
      (txt, token) <- AP.match tokenOrComment
      return $ (Text.length txt, token)

    tokenOrComment = ((const Nothing) <$> skipP) <|> (Just <$> tokenP)
    skipP = many1 space *> pure () <|> javaStyleComment

-- | Remove all imports from parsed java code
removeImports :: TokenVector Token Java -> TokenVector Token Java
removeImports v = id $! V.fromList (f lst)
  where
    lst = V.toList v
    f [] = []
    f (t:ts) | token t == TokenImport =
               case dropWhile (\tok -> token tok /= TokenSemicolon) ts of
                 [] -> []
                 (_:rest) -> f rest
             | otherwise =
                 let (allowed, rest) = span (\x -> token x /= TokenImport) (t:ts)
                 in allowed ++ (f rest)
tokenP :: Parser Token
tokenP = "<" *> pure TokenLT
         <|> ">" *> pure TokenGT
         <|> "==" *> pure TokenEQ
         <|> "=" *> pure TokenAssign
         <|> "!" *> pure TokenNot
         <|> "&" *> pure TokenBinAnd
         <|> "&&" *> pure TokenAnd
         <|> "|" *> pure TokenBinOr
         <|> "||" *> pure TokenOr
         <|> "+" *> pure TokenAdd
         <|> "*" *> pure TokenMult
         <|> "-" *> pure TokenSub
         <|> "/" *> pure TokenDiv
         <|> "%" *> pure TokenMod
         <|> "(" *> pure TokenLParen
         <|> ")" *> pure TokenRParen
         <|> "[" *> pure TokenLBrack
         <|> "]" *> pure TokenRBrack
         <|> "{" *> pure TokenLBrace
         <|> "}" *> pure TokenRBrace
         <|> "." *> pure TokenDot
         <|> "," *> pure TokenComma
         <|> ":" *> pure TokenColon
         <|> "?" *> pure TokenQuestion
         <|> ";" *> pure TokenSemicolon
         <|> followedByNonAlphaNum "break" *> pure TokenBreak
         <|> followedByNonAlphaNum "import" *> pure TokenImport
         <|> followedByNonAlphaNum "return" *> pure TokenReturn
         <|> followedByNonAlphaNum modifier
         <|> followedByNonAlphaNum loopWord
         <|> followedByNonAlphaNum keyword
         <|> followedByNonAlphaNum primitive
         <|> tokenNumber
         <|> label
         <|> identifier
         <|> stringLiteral *> pure TokenStringLiteral
         <|> characterLiteral *> pure TokenCharacterLiteral
         <|> annotation

followedByNonAlphaNum :: Parser a -> Parser a
followedByNonAlphaNum parser = do
  x <- parser
  peekVal <- peekChar
  case peekVal of
    Nothing -> return x
    Just c | isAlphaNum c -> fail "Followed by alpha num"
           | otherwise -> return x

keyword :: Parser Token
keyword = tokenCondition <|> tokenClassStructure <|> tokenKeyword <|> tokenBool
  where
    tokenBool = ("true" <|> "false") *> pure TokenBooleanValue
    tokenCondition = ("if"
                      <|> "else"
                      <|> "switch"
                      <|> "case"
                     ) *> pure TokenKeywordCondition
    tokenClassStructure = ( "class"
                            <|> "interface" ) *> pure TokenKeywordClassStructure
    tokenKeyword = ( "package"
                     <|> "null"
                     <|> "throw"
                     <|> "try"
                     <|> "catch"
                     <|> "finally"
                     <|> "throws"
                     <|> "super"
                     <|> "this"
                     <|> "new"
                     <|> "continue"
                     <|> "goto"
                     <|> "synchronized"
                     <|> "enum"
                     <|> "assert"
                   ) *> pure TokenKeyword

-- | A parser for tokens that are used to declare looping constructs
loopWord :: Parser Token
loopWord = ("do"
            <|> "while"
            <|> "for"
           ) *> pure TokenLoopWord

-- | A parser vor visibility modifiers of identifiers
modifier :: Parser Token
modifier = ("public"
           <|> "private"
           <|> "protected"
           <|> "static"
           <|> "final"
           <|> "volatile"
           ) *> pure TokenModifier

-- | Atomic types in java
primitive :: Parser Token
primitive = ("byte"
             <|> "char"
             <|> "short"
             <|> "int"
             <|> "long"
             <|> "float"
             <|> "double"
             <|> "boolean"
             <|> "void") *> pure TokenPrimitive

-- | Annotations starting with an \@ symbol
annotation :: Parser Token
annotation = char '@' *> identifier *> pure TokenAnnotation

label :: Parser Token
label = identifier *> many' (char ' ') *> ":" *> pure TokenLabel

identifier :: Parser Token
identifier = do
  satisfy nonDigit
  AP.takeWhile (\c -> or $ ($ c) <$> [isAlphaNum, nonDigit])
  return TokenIdentifier
  where
    nonDigit c = isAlpha c || c == '_' || c == '$'

tokenNumber :: Parser Token
tokenNumber = tokenHexadecimal <|> tokenStandardNumber

tokenStandardNumber = do
  scientific
  char 'd' <|> char 'f' <|> pure undefined
  return TokenNumber

tokenHexadecimal :: Parser Token
tokenHexadecimal = do
  "0x"
  takeWhile1 (\c -> isDigit c || c `elem` ("abcdef" :: String))
  return TokenNumber

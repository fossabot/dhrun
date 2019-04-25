{-# language DerivingStrategies #-}
{-# language LambdaCase #-}
{-# language FlexibleContexts #-}
{-# language RecordWildCards #-}
{-# language DataKinds #-}
{-# language FlexibleInstances #-}
{-# language ScopedTypeVariables #-}
{-# language TypeOperators #-}
{-# language NoImplicitPrelude #-}

{-|
Module      : Dhrun.Run
Description : runner
Copyright   : (c) Valentin Reis, 2018
License     : MIT
Maintainer  : fre@freux.fr
-}

module Dhrun.Conduit
  ( makeBehavior
  )
where

import           Dhrun.Types.Cfg
import           Dhrun.Pure
import           Protolude
import           Data.Conduit                   ( ConduitT
                                                , yield
                                                , await
                                                )
import qualified Data.ByteString               as B
import           Control.Exception.Base         ( throw )


-- | makeBehavior builds an IO conduit that throws a PatternMatched when
-- all wanted pattern or one avoided pattern are found
makeBehavior :: (Monad m) => Check -> ConduitT ByteString ByteString m ()
makeBehavior c = case wants c of
  [] -> cleanLooper c
  as -> expectfulLooper c $ toS <$> as

expectfulLooper
  :: (Monad m) => Check -> [ByteString] -> ConduitT ByteString ByteString m ()
expectfulLooper _ [] = throw ThrowFoundAllWants
expectfulLooper c l  = noAvoidsAndOtherwise c $ \b ->
  yield b >> expectfulLooper c (filter (not . flip B.isInfixOf b) (toS <$> l))

cleanLooper :: (Monad m) => Check -> ConduitT ByteString ByteString m ()
cleanLooper c = noAvoidsAndOtherwise c $ \b -> yield b >> cleanLooper c

noAvoidsAndOtherwise
  :: (Monad m)
  => Check
  -> (ByteString -> ConduitT ByteString ByteString m ())
  -> ConduitT ByteString ByteString m ()
noAvoidsAndOtherwise Check {..} otherwiseConduit = await >>= \case
  Just b -> case filter (`B.isInfixOf` b) (toS <$> avoids) of
    []     -> otherwiseConduit b
    xh : _ -> yield b >> throw (ThrowFoundAnAvoid $ toS xh)
  Nothing -> return ()

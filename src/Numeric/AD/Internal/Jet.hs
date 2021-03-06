{-# LANGUAGE TypeOperators, TemplateHaskell, ScopedTypeVariables, FlexibleContexts #-}
{-# OPTIONS_HADDOCK hide #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Numeric.AD.Internal.Jet
-- Copyright   :  (c) Edward Kmett 2010
-- License     :  BSD3
-- Maintainer  :  ekmett@gmail.com
-- Stability   :  experimental
-- Portability :  GHC only
--
-----------------------------------------------------------------------------

module Numeric.AD.Internal.Jet
    ( Jet(..)
    , headJet
    , tailJet
    , jet
    ) where

#ifndef MIN_VERSION_base
#define MIN_VERSION_base(x,y,z) 1
#endif

import Control.Applicative
import Data.Foldable
import Data.Traversable
import Data.Monoid
#if MIN_VERSION_base(4,4,0)
import Data.Typeable (Typeable1(..), TyCon, mkTyCon3, mkTyConApp)
#else
import Data.Typeable (Typeable1(..), TyCon, mkTyCon, mkTyConApp)
#endif
import Control.Comonad.Cofree

infixl 3 :-

-- | A jet is a tower of all (higher order) partial derivatives of a function
data Jet f a = a :- Jet f (f a)

newtype Showable = Showable (Int -> String -> String)

instance Show Showable where
  showsPrec d (Showable f) = f d

showable :: Show a => a -> Showable
showable a = Showable (\d -> showsPrec d a)

-- Polymorphic recursion precludes 'Data' in its current form, as no Data1 class exists
-- Polymorphic recursion also breaks 'show' for 'Jet'!
-- factor Show1 out of Lifted?
instance (Functor f, Show (f Showable), Show a) => Show (Jet f a) where
  showsPrec d (a :- as) = showParen (d > 3) $
    showsPrec 4 a . showString " :- " . showsPrec 3 (fmap showable <$> as)

instance Functor f => Functor (Jet f) where
    fmap f (a :- as) = f a :- fmap (fmap f) as

instance Foldable f => Foldable (Jet f) where
    foldMap f (a :- as) = f a `mappend` foldMap (foldMap f) as

instance Traversable f => Traversable (Jet f) where
    traverse f (a :- as) = (:-) <$> f a <*> traverse (traverse f) as

tailJet :: Jet f a -> Jet f (f a)
tailJet (_ :- as) = as
{-# INLINE tailJet #-}

headJet :: Jet f a -> a
headJet (a :- _) = a
{-# INLINE headJet #-}

jet :: Functor f => Cofree f a -> Jet f a
jet (a :< as) = a :- dist (jet <$> as)
    where
        dist :: Functor f => f (Jet f a) -> Jet f (f a)
        dist x = (headJet <$> x) :- dist (tailJet <$> x)

instance Typeable1 f => Typeable1 (Jet f) where
    typeOf1 tfa = mkTyConApp jetTyCon [typeOf1 (undefined `asArgsType` tfa)]
        where asArgsType :: f a -> t f a -> f a
              asArgsType = const

jetTyCon :: TyCon
#if MIN_VERSION_base(4,4,0)
jetTyCon = mkTyCon3 "ad" "Numeric.AD.Internal.Jet" "Jet"
#else
jetTyCon = mkTyCon "Numeric.AD.Internal.Jet.Jet"
#endif
{-# NOINLINE jetTyCon #-}

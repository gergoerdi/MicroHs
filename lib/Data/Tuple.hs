-- Copyright 2023 Lennart Augustsson
-- See LICENSE file for full license.
module Data.Tuple(
  module Data.Tuple,
  ()(..)
  ) where
import Primitives  -- for ()
import Data.Bool
import Data.Bounded
import Data.Eq
import Data.Function
import Data.Monoid
import Data.Record
import Data.Semigroup
import Text.Show

--data (a,b) = (a,b)  -- all tuples are built in
--data (a,b,c) = (a,b,c)
-- etc

fst :: forall a b . (a, b) -> a
fst (a, _) = a

snd :: forall a b . (a, b) -> b
snd (_, b) = b

-----------------------------------

instance Eq () where
  () == ()  =  True

instance forall a b . (Eq a, Eq b) => Eq (a, b) where
  (a1, b1) == (a2, b2)  =  a1 == a2 && b1 == b2

instance forall a b c . (Eq a, Eq b, Eq c) => Eq (a, b, c) where
  (a1, b1, c1) == (a2, b2, c2)  =  a1 == a2 && b1 == b2 && c1 == c2

instance forall a b c d . (Eq a, Eq b, Eq c, Eq d) => Eq (a, b, c, d) where
  (a1, b1, c1, d1) == (a2, b2, c2, d2)  =  a1 == a2 && b1 == b2 && c1 == c2 && d1 == d2

-----------------------------------

instance Show () where
  showsPrec _ () = showString "()"

instance forall a b . (Show a, Show b) => Show (a, b) where
  showsPrec _ (a, b) = showParen True (showsPrec 0 a . showString "," . showsPrec 0 b)

instance forall a b c . (Show a, Show b, Show c) => Show (a, b, c) where
  showsPrec _ (a, b, c) = showParen True (showsPrec 0 a . showString "," . showsPrec 0 b . showString "," . showsPrec 0 c)

instance forall a b c d . (Show a, Show b, Show c, Show d) => Show (a, b, c, d) where
  showsPrec _ (a, b, c, d) = showParen True (showsPrec 0 a . showString "," . showsPrec 0 b . showString "," . showsPrec 0 c .
                                             showString "," . showsPrec 0 d)

-----------------------------------

instance Bounded () where
  minBound = ()
  maxBound = ()

instance forall a b . (Bounded a, Bounded b) => Bounded (a, b) where
  minBound = (minBound, minBound)
  maxBound = (maxBound, maxBound)

instance forall a b c . (Bounded a, Bounded b, Bounded c) => Bounded (a, b, c) where
  minBound = (minBound, minBound, minBound)
  maxBound = (maxBound, maxBound, maxBound)

instance forall a b c d . (Bounded a, Bounded b, Bounded c, Bounded d) => Bounded (a, b, c, d) where
  minBound = (minBound, minBound, minBound, minBound)
  maxBound = (maxBound, maxBound, maxBound, maxBound)

-----------------------------------

instance Semigroup () where
  _ <> _ = ()

instance forall a b . (Semigroup a, Semigroup b) => Semigroup (a, b) where
  (a, b) <> (a', b') = (a <> a', b <> b')

instance forall a b c . (Semigroup a, Semigroup b, Semigroup c) => Semigroup (a, b, c) where
  (a, b, c) <> (a', b', c') = (a <> a', b <> b', c <> c')

instance forall a b c d . (Semigroup a, Semigroup b, Semigroup c, Semigroup d) => Semigroup (a, b, c, d) where
  (a, b, c, d) <> (a', b', c', d') = (a <> a', b <> b', c <> c', d <> d')

-----------------------------------

instance Monoid () where
  mempty = ()

instance forall a b . (Monoid a, Monoid b) => Monoid (a, b) where
  mempty = (mempty, mempty)

instance forall a b c . (Monoid a, Monoid b, Monoid c) => Monoid (a, b, c) where
  mempty = (mempty, mempty, mempty)

instance forall a b c d . (Monoid a, Monoid b, Monoid c, Monoid d) => Monoid (a, b, c, d) where
  mempty = (mempty, mempty, mempty, mempty)

-----------------------------------
-- Virtual fields for tuples.

instance forall a b . HasField "_1" (a, b) a where
  hasField _ (a, b) = (a, \ a -> (a, b))
instance forall a b . HasField "_2" (a, b) b where
  hasField _ (a, b) = (b, \ b -> (a, b))

instance forall a b c . HasField "_1" (a, b, c) a where
  hasField _ (a, b, c) = (a, \ a -> (a, b, c))
instance forall a b c . HasField "_2" (a, b, c) b where
  hasField _ (a, b, c) = (b, \ b -> (a, b, c))
instance forall a b c . HasField "_3" (a, b, c) c where
  hasField _ (a, b, c) = (c, \ c -> (a, b, c))

instance forall a b c d . HasField "_1" (a, b, c, d) a where
  hasField _ (a, b, c, d) = (a, \ a -> (a, b, c, d))
instance forall a b c d . HasField "_2" (a, b, c, d) b where
  hasField _ (a, b, c, d) = (b, \ b -> (a, b, c, d))
instance forall a b c d . HasField "_3" (a, b, c, d) c where
  hasField _ (a, b, c, d) = (c, \ c -> (a, b, c, d))
instance forall a b c d . HasField "_4" (a, b, c, d) d where
  hasField _ (a, b, c, d) = (d, \ d -> (a, b, c, d))

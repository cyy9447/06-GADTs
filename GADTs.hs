-- Allow data to be used in types
{-# LANGUAGE DataKinds           #-}
-- Constrain datatypes via indices
{-# LANGUAGE GADTs               #-}
-- Allow kind annotations on types
{-# LANGUAGE KindSignatures      #-}
-- Bind polymorphic type variables
{-# LANGUAGE ScopedTypeVariables #-}
-- Use 'Type' instead of '*' in kinds
{-# LANGUAGE NoStarIsType        #-}
{-# OPTIONS_GHC -Wincomplete-patterns #-}
{-# OPTIONS_GHC -Wno-unticked-promoted-constructors #-}

module GADTs where

import           Data.Kind  (Type)
import           Data.Maybe (fromMaybe)
import           Test.HUnit

data OExp
  = OInt Int -- a number constant, like '2'
  | OBool Bool -- a boolean constant, like 'true'
  | OAdd OExp OExp -- add two expressions, like 'e1 + e2'
  | OIsZero OExp -- test if an expression is zero
  | OIf OExp OExp OExp -- if expression, 'if e1 then e2 else e3'
  deriving (Eq, Show)

-- The expression "1 + 3"
oe1 :: OExp
oe1 = OAdd (OInt 1) (OInt 3)

-- The expression "if (3 + -3) == 0 then 3 else 4"
oe2 :: OExp
oe2 = OIf (OIsZero (OAdd (OInt 3) (OInt (-3)))) (OInt 3) (OInt 4)

oevaluate :: OExp -> Maybe (Either Int Bool)
oevaluate (OInt i) = Just (Left i)
oevaluate (OBool b) = Just (Right b)
oevaluate (OAdd e1 e2) =
  case (oevaluate e1, oevaluate e2) of
    (Just (Left i1), Just (Left i2)) -> Just (Left (i1 + i2))
    _                                -> Nothing
oevaluate (OIsZero e1) =
  case oevaluate e1 of
    Just (Left x) -> if x == 0 then Just (Right True) else Just (Right False)
    _             -> Nothing
oevaluate (OIf e1 e2 e3) =
  case oevaluate e1 of
    Just (Right b) -> if b then oevaluate e2 else oevaluate e3
    _              -> Nothing

oe1_example :: Maybe (Either Int Bool)
oe1_example = oevaluate oe1

oe2_test :: Test
oe2_test = oevaluate oe2 ~?= Just (Left 3)

bad_oe1 :: OExp
bad_oe1 = OAdd (OBool True) (OInt 1)

bad_oe2 :: OExp
bad_oe2 = OIf (OInt 1) (OBool True) (OInt 3)

data SExp where
  SInt :: Int -> SExp
  SBool :: Bool -> SExp
  SAdd :: SExp -> SExp -> SExp
  SIsZero :: SExp -> SExp
  SIf :: SExp -> SExp -> SExp -> SExp

data GExp :: Type -> Type where
  GInt :: Int -> GExp Int
  GBool :: Bool -> GExp Bool
  GAdd :: GExp Int -> GExp Int -> GExp Int
  GIsZero :: GExp Int -> GExp Bool
  GIf :: GExp Bool -> GExp a -> GExp a -> GExp a

ge1 :: GExp Bool
ge1 = GIsZero (GAdd (GInt 1) (GInt 3))

ge2 :: GExp Int
ge2 = GIf (GBool True) (GInt 3) (GInt 4)

-- bad_ge1 :: GExp Int
-- bad_ge1 = GAdd (GBool True) (GInt 1)

-- bad_ge2 :: GExp Int
-- bad_ge2 = GIf (GInt 1) (GBool True) (GInt 3)

-- bad_ge3 :: GExp Int
-- bad_ge3 = GIf (GBool True) (GInt 1) (GBool True)

evaluate :: GExp t -> t
evaluate (GInt i) = i
evaluate (GBool b) = b
evaluate (GAdd e1 e2) = evaluate e1 + evaluate e2
evaluate (GIsZero e1) =
  case evaluate e1 of
    0 -> True
    _ -> False
evaluate (GIf e1 e2 e3) =
  if evaluate e1 then evaluate e2 else evaluate e3

data T (a :: Type -> Type) = MkT (a Int)

data U (a :: Bool) = MkU

exUT :: U 'True
exUT = MkU

exUF :: U 'False
exUF = MkU

-- This line doesn't type check because (==) requires arguments with the same types.
-- ex = exUT == exUF

data Flag = Empty | NonEmpty

data List :: Flag -> Type -> Type where
  Nil :: List 'Empty a
  Cons :: a -> List f a -> List 'NonEmpty a

ex0 :: List 'Empty Int
ex0 = Nil

ex1 :: List 'NonEmpty Int
ex1 = Cons 1 (Cons 2 (Cons 3 Nil))

safeHd :: List NonEmpty a -> a
safeHd (Cons h _) = h

--unsafeHd :: [a] -> a
--unsafeHd (x : _) = x

foldr' :: forall a b f. (a -> b -> b) -> b -> List f a -> b
foldr' f z = go
  where
    go :: forall f'. List f' a -> b
    go Nil         = z
    go (Cons x xs) = f x (go xs)

foldr1' :: forall a. (a -> a -> a) -> List NonEmpty a -> a
foldr1' f = go
  where
    go :: List NonEmpty a -> a
    go (Cons x Nil)         = x
    go (Cons x (Cons y ys)) = f x (go (Cons y ys))

map' :: forall a b f. (a -> b) -> List f a -> List f b
map' f = go
  where
    go :: forall f'. List f' a -> List f' b
    go Nil         = Nil
    go (Cons x xs) = Cons (f x) (go xs)

-- filter' :: (a -> Bool) -> List f a -> List f a

-- filter' :: (a -> Bool) -> List f a -> List f' a

data (OldList a) :: Type where
  OL :: List f a -> OldList a

isNonempty :: OldList a -> Maybe (List NonEmpty a)
isNonempty (OL Nil)           = Nothing
isNonempty (OL xs@(Cons _ _)) = Just xs

filter' :: forall a f. (a -> Bool) -> List f a -> OldList a
filter' p = go
  where
    go :: forall f'. List f' a -> OldList a
    go Nil = OL Nil
    go (Cons x xs)
      | not . p $ x = go xs
      | otherwise =
          case isNonempty (go xs) of
            Nothing -> OL (Cons x Nil)
            Just xs -> OL (Cons x xs)


-- silly :: forall f. Bool -> List f ()
-- silly False = Nil
-- silly True  = Cons () Nil
